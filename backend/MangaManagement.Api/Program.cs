using Microsoft.Data.Sqlite;

var builder = WebApplication.CreateBuilder(args);
if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ASPNETCORE_URLS"))
    && !args.Any(argument => argument.StartsWith("--urls", StringComparison.OrdinalIgnoreCase)))
{
    builder.WebHost.UseUrls("http://127.0.0.1:5080");
}
var dbPath = Path.Combine(builder.Environment.ContentRootPath, "manga_management.db");
var connectionString = new SqliteConnectionStringBuilder { DataSource = dbPath }.ToString();
builder.Services.AddCors(options => options.AddDefaultPolicy(policy =>
    policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
app.UseCors();
await InitializeDatabase(connectionString);

bool CanManage(HttpRequest request) =>
    request.Headers["X-User-Role"].ToString().ToLowerInvariant() is "staff" or "admin";
bool IsAdmin(HttpRequest request) =>
    request.Headers["X-User-Role"].ToString().Equals("admin", StringComparison.OrdinalIgnoreCase);

app.MapGet("/api/health", () => Results.Ok(new { status = "ok", database = "sqlite" }));

app.MapGet("/api/genres", async () =>
{
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "SELECT id, name FROM genres ORDER BY name COLLATE NOCASE";
    await using var reader = await command.ExecuteReaderAsync();
    var rows = new List<object>();
    while (await reader.ReadAsync()) rows.Add(new { id = reader.GetString(0), name = reader.GetString(1) });
    return Results.Ok(rows);
});

app.MapPost("/api/genres", async (GenreInput input, HttpRequest request) =>
{
    if (!CanManage(request)) return Results.StatusCode(403);
    var name = input.Name?.Trim() ?? "";
    if (name.Length is < 1 or > 40) return Results.BadRequest(new { message = "Tên thể loại phải có từ 1 đến 40 ký tự." });
    await using var db = await OpenDb(connectionString);
    var id = string.IsNullOrWhiteSpace(input.Id) ? Guid.NewGuid().ToString() : input.Id;
    try
    {
        await using var command = db.CreateCommand();
        command.CommandText = "INSERT INTO genres(id,name) VALUES($id,$name)";
        command.Parameters.AddWithValue("$id", id);
        command.Parameters.AddWithValue("$name", name);
        await command.ExecuteNonQueryAsync();
        return Results.Created($"/api/genres/{id}", new { id, name });
    }
    catch (SqliteException ex) when (ex.SqliteErrorCode == 19)
    {
        return Results.Conflict(new { message = "Tên thể loại đã tồn tại." });
    }
});

app.MapPut("/api/genres/{id}", async (string id, GenreInput input, HttpRequest request) =>
{
    if (!CanManage(request)) return Results.StatusCode(403);
    var name = input.Name?.Trim() ?? "";
    if (name.Length is < 1 or > 40) return Results.BadRequest(new { message = "Tên thể loại phải có từ 1 đến 40 ký tự." });
    await using var db = await OpenDb(connectionString);
    try
    {
        await using var transaction = await db.BeginTransactionAsync();
        await using var oldNameCommand = db.CreateCommand();
        oldNameCommand.Transaction = (SqliteTransaction)transaction;
        oldNameCommand.CommandText = "SELECT name FROM genres WHERE id=$id";
        oldNameCommand.Parameters.AddWithValue("$id", id);
        var oldName = await oldNameCommand.ExecuteScalarAsync() as string;
        if (oldName is null) return Results.NotFound();
        await using var update = db.CreateCommand();
        update.Transaction = (SqliteTransaction)transaction;
        update.CommandText = "UPDATE genres SET name=$name WHERE id=$id";
        update.Parameters.AddWithValue("$name", name);
        update.Parameters.AddWithValue("$id", id);
        var changed = await update.ExecuteNonQueryAsync();
        if (changed == 0) return Results.NotFound();
        await using var mangas = db.CreateCommand();
        mangas.Transaction = (SqliteTransaction)transaction;
        mangas.CommandText = "UPDATE mangas SET genre=$new WHERE genre=$old";
        mangas.Parameters.AddWithValue("$new", name);
        mangas.Parameters.AddWithValue("$old", oldName);
        await mangas.ExecuteNonQueryAsync();
        await transaction.CommitAsync();
        return Results.Ok(new { id, name });
    }
    catch (SqliteException ex) when (ex.SqliteErrorCode == 19)
    {
        return Results.Conflict(new { message = "Tên thể loại đã tồn tại." });
    }
});

app.MapDelete("/api/genres/{id}", async (string id, HttpRequest request) =>
{
    if (!CanManage(request)) return Results.StatusCode(403);
    await using var db = await OpenDb(connectionString);
    await using var transaction = await db.BeginTransactionAsync();
    await using var nameCommand = db.CreateCommand();
    nameCommand.Transaction = (SqliteTransaction)transaction;
    nameCommand.CommandText = "SELECT name FROM genres WHERE id=$id";
    nameCommand.Parameters.AddWithValue("$id", id);
    var name = await nameCommand.ExecuteScalarAsync() as string;
    if (name is null) return Results.NotFound();
    await using var used = db.CreateCommand();
    used.Transaction = (SqliteTransaction)transaction;
    used.CommandText = "SELECT COUNT(*) FROM mangas WHERE genre=$name";
    used.Parameters.AddWithValue("$name", name);
    var count = Convert.ToInt32(await used.ExecuteScalarAsync());
    if (count > 0) return Results.Conflict(new { message = $"Thể loại đang được {count} truyện sử dụng." });
    await using var delete = db.CreateCommand();
    delete.Transaction = (SqliteTransaction)transaction;
    delete.CommandText = "DELETE FROM genres WHERE id=$id";
    delete.Parameters.AddWithValue("$id", id);
    await delete.ExecuteNonQueryAsync();
    await transaction.CommitAsync();
    return Results.NoContent();
});

app.MapGet("/api/mangas", async (string? q, string? genre, bool? includeHidden, HttpRequest request) =>
{
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    var filters = new List<string>();
    if (!string.IsNullOrWhiteSpace(q))
    {
        filters.Add("(title LIKE $q OR author LIKE $q)");
        command.Parameters.AddWithValue("$q", $"%{q.Trim()}%");
    }
    if (!string.IsNullOrWhiteSpace(genre) && genre != "Tất cả")
    {
        filters.Add("genre=$genre");
        command.Parameters.AddWithValue("$genre", genre.Trim());
    }
    if (includeHidden != true || !CanManage(request)) filters.Add("is_hidden=0");
    command.CommandText = $"SELECT id,title,author,description,cover_url,genre,status,total_chapters,current_chapter,rating,is_favorite,is_hidden FROM mangas {(filters.Count == 0 ? "" : "WHERE " + string.Join(" AND ", filters))} ORDER BY title COLLATE NOCASE";
    await using var reader = await command.ExecuteReaderAsync();
    var mangas = new List<object>();
    while (await reader.ReadAsync()) mangas.Add(ReadManga(reader));
    return Results.Ok(mangas);
});

app.MapGet("/api/mangas/{id}", async (string id, HttpRequest request) =>
{
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "SELECT id,title,author,description,cover_url,genre,status,total_chapters,current_chapter,rating,is_favorite,is_hidden FROM mangas WHERE id=$id AND (is_hidden=0 OR $staff=1)";
    command.Parameters.AddWithValue("$id", id);
    command.Parameters.AddWithValue("$staff", CanManage(request) ? 1 : 0);
    await using var reader = await command.ExecuteReaderAsync();
    return await reader.ReadAsync() ? Results.Ok(ReadManga(reader)) : Results.NotFound();
});

app.MapPost("/api/mangas", async (MangaInput manga, HttpRequest request) =>
{
    if (!CanManage(request)) return Results.StatusCode(403);
    var issue = ValidateManga(manga);
    if (issue is not null) return Results.BadRequest(new { message = issue });
    var id = string.IsNullOrWhiteSpace(manga.Id) ? Guid.NewGuid().ToString() : manga.Id;
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "INSERT INTO mangas(id,title,author,description,cover_url,genre,status,total_chapters,current_chapter,rating,is_favorite,is_hidden) VALUES($id,$title,$author,$description,$cover,$genre,$status,$total,$current,$rating,$favorite,$hidden)";
    BindManga(command, manga, id);
    await command.ExecuteNonQueryAsync();
    return Results.Created($"/api/mangas/{id}", MangaDto(manga, id));
});

app.MapPut("/api/mangas/{id}", async (string id, MangaInput manga, HttpRequest request) =>
{
    if (!CanManage(request)) return Results.StatusCode(403);
    var issue = ValidateManga(manga);
    if (issue is not null) return Results.BadRequest(new { message = issue });
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "UPDATE mangas SET title=$title,author=$author,description=$description,cover_url=$cover,genre=$genre,status=$status,total_chapters=$total,current_chapter=$current,rating=$rating,is_favorite=$favorite,is_hidden=$hidden WHERE id=$id";
    BindManga(command, manga, id);
    if (await command.ExecuteNonQueryAsync() == 0) return Results.NotFound();
    return Results.Ok(MangaDto(manga, id));
});

app.MapPatch("/api/mangas/{id}/visibility", async (string id, VisibilityInput input, HttpRequest request) =>
{
    if (!CanManage(request)) return Results.StatusCode(403);
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "UPDATE mangas SET is_hidden=$hidden WHERE id=$id";
    command.Parameters.AddWithValue("$hidden", input.Hidden ? 1 : 0);
    command.Parameters.AddWithValue("$id", id);
    return await command.ExecuteNonQueryAsync() == 0 ? Results.NotFound() : Results.NoContent();
});

app.MapPatch("/api/mangas/{id}/favorite", async (string id, FavoriteInput input, HttpRequest request) =>
{
    if (request.Headers["X-User-Role"].ToString().Equals("guest", StringComparison.OrdinalIgnoreCase)) return Results.StatusCode(403);
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "UPDATE mangas SET is_favorite=$favorite WHERE id=$id";
    command.Parameters.AddWithValue("$favorite", input.IsFavorite ? 1 : 0);
    command.Parameters.AddWithValue("$id", id);
    return await command.ExecuteNonQueryAsync() == 0 ? Results.NotFound() : Results.NoContent();
});

app.MapPatch("/api/mangas/{id}/progress", async (string id, ProgressInput input, HttpRequest request) =>
{
    if (request.Headers["X-User-Role"].ToString().Equals("guest", StringComparison.OrdinalIgnoreCase)) return Results.StatusCode(403);
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "UPDATE mangas SET current_chapter=MIN(MAX($chapter,0),total_chapters) WHERE id=$id";
    command.Parameters.AddWithValue("$chapter", input.CurrentChapter);
    command.Parameters.AddWithValue("$id", id);
    return await command.ExecuteNonQueryAsync() == 0 ? Results.NotFound() : Results.NoContent();
});

app.MapDelete("/api/mangas/{id}", async (string id, HttpRequest request) =>
{
    if (!IsAdmin(request)) return Results.StatusCode(403);
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "DELETE FROM mangas WHERE id=$id";
    command.Parameters.AddWithValue("$id", id);
    return await command.ExecuteNonQueryAsync() == 0 ? Results.NotFound() : Results.NoContent();
});

app.MapGet("/api/mangas/{id}/chapters", async (string id, HttpRequest request) =>
{
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = "SELECT c.id,c.manga_id,c.chapter_number,c.title,c.contents,c.created_at,c.updated_at,c.is_locked,c.is_deleted,c.price FROM chapters c JOIN mangas m ON m.id=c.manga_id WHERE c.manga_id=$id AND c.is_deleted=0 AND (m.is_hidden=0 OR $staff=1) ORDER BY c.chapter_number";
    command.Parameters.AddWithValue("$id", id);
    command.Parameters.AddWithValue("$staff", CanManage(request) ? 1 : 0);
    await using var reader = await command.ExecuteReaderAsync();
    var chapters = new List<object>();
    while (await reader.ReadAsync())
    {
        chapters.Add(new
        {
            id = reader.GetString(0), mangaId = reader.GetString(1), chapterNumber = reader.GetInt32(2),
            title = reader.GetString(3), contents = reader.GetString(4), createdAt = reader.GetString(5),
            updatedAt = reader.GetString(6), isLocked = reader.GetInt32(7) != 0,
            isDeleted = reader.GetInt32(8) != 0, price = reader.GetDouble(9)
        });
    }
    return Results.Ok(chapters);
});

app.MapGet("/api/statistics/catalog", async (HttpRequest request) =>
{
    if (!IsAdmin(request)) return Results.StatusCode(403);
    await using var db = await OpenDb(connectionString);
    async Task<int> Count(string sql)
    {
        await using var command = db.CreateCommand();
        command.CommandText = sql;
        var value = await command.ExecuteScalarAsync();
        return Convert.ToInt32(value);
    }
    return Results.Ok(new
    {
        totalMangas = await Count("SELECT COUNT(*) FROM mangas"),
        hiddenMangas = await Count("SELECT COUNT(*) FROM mangas WHERE IFNULL(is_hidden,0)=1"),
        totalChapters = await Count("SELECT COUNT(*) FROM chapters WHERE is_deleted=0"),
        lockedChapters = await Count("SELECT COUNT(*) FROM chapters WHERE is_deleted=0 AND is_locked=1 AND price>0"),
        totalGenres = await Count("SELECT COUNT(*) FROM genres"),
        source = "aspnet-catalog",
        note = "X-User-Role chỉ phục vụ local mock, không phải cơ chế phân quyền production."
    });
});

app.Run();

static async Task<SqliteConnection> OpenDb(string connectionString)
{
    var db = new SqliteConnection(connectionString);
    await db.OpenAsync();
    await using var command = db.CreateCommand();
    command.CommandText = "PRAGMA foreign_keys=ON;";
    await command.ExecuteNonQueryAsync();
    return db;
}

static async Task InitializeDatabase(string connectionString)
{
    await using var db = await OpenDb(connectionString);
    await using var command = db.CreateCommand();
    command.CommandText = """
      CREATE TABLE IF NOT EXISTS genres(id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE);
      CREATE TABLE IF NOT EXISTS mangas(
        id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
        cover_url TEXT NOT NULL DEFAULT '', genre TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Ongoing',
        total_chapters INTEGER NOT NULL DEFAULT 0, current_chapter INTEGER NOT NULL DEFAULT 0,
        rating REAL NOT NULL DEFAULT 0, is_favorite INTEGER NOT NULL DEFAULT 0, is_hidden INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS chapters(
        id TEXT PRIMARY KEY, manga_id TEXT NOT NULL, chapter_number INTEGER NOT NULL, title TEXT NOT NULL,
        contents TEXT NOT NULL DEFAULT '[]', created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        is_locked INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0, price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(manga_id) REFERENCES mangas(id) ON DELETE CASCADE);
      """;
    await command.ExecuteNonQueryAsync();
    foreach (var genre in new[] { "Action", "Adventure", "Fantasy", "Comedy", "Romance", "Supernatural", "Sports" })
    {
        await using var seed = db.CreateCommand();
        seed.CommandText = "INSERT OR IGNORE INTO genres(id,name) VALUES($id,$name)";
        seed.Parameters.AddWithValue("$id", genre.ToLowerInvariant());
        seed.Parameters.AddWithValue("$name", genre);
        await seed.ExecuteNonQueryAsync();
    }
    var now = DateTime.UtcNow.ToString("O");
    var seedMangas = new[]
    {
        new MangaInput("1", "One Piece", "Eiichiro Oda", "Cuộc phiêu lưu tìm kho báu One Piece.", "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80", "Action", "Ongoing", 1115, 1080, 9.8, false, false),
        new MangaInput("2", "Solo Leveling", "Chugong", "Thợ săn yếu nhất trở thành thợ săn mạnh nhất.", "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600&auto=format&fit=crop&q=80", "Fantasy", "Completed", 200, 200, 9.6, true, false),
        new MangaInput("3", "Frieren: Beyond Journey's End", "Kanehito Yamada", "Hành trình của pháp sư Elf Frieren.", "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80", "Adventure", "Ongoing", 130, 95, 9.7, false, false),
        new MangaInput("4", "Jujutsu Kaisen", "Gege Akutami", "Yuji bước vào thế giới chú thuật.", "https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&auto=format&fit=crop&q=80", "Action", "Completed", 271, 271, 9.2, false, false),
        new MangaInput("5", "Spy x Family", "Tatsuya Endo", "Một gia đình điệp viên với những bí mật riêng.", "https://images.unsplash.com/photo-1563089145-599997674d42?w=600&auto=format&fit=crop&q=80", "Comedy", "Ongoing", 104, 75, 9.4, true, false),
        new MangaInput("6", "Blue Lock", "Muneyuki Kaneshiro", "Cuộc tuyển chọn tiền đạo xuất sắc nhất.", "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80", "Sports", "Ongoing", 280, 240, 9.1, false, false)
    };
    foreach (var manga in seedMangas)
    {
        await using var seed = db.CreateCommand();
        seed.CommandText = "INSERT OR IGNORE INTO mangas(id,title,author,description,cover_url,genre,status,total_chapters,current_chapter,rating,is_favorite,is_hidden) VALUES($id,$title,$author,$description,$cover,$genre,$status,$total,$current,$rating,$favorite,$hidden)";
        BindManga(seed, manga, manga.Id!);
        await seed.ExecuteNonQueryAsync();
    }
    var seedChapters = new[]
    {
        ("c1_1", "1", 1, "Bình minh của cuộc phiêu lưu", "[\"https://images.unsplash.com/photo-1578632767115-351597cf2477?w=900\",\"https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=900\"]", 0, 0.0),
        ("c1_2", "1", 2, "Cậu bé Mũ Rơm Luffy", "[\"https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=900\"]", 0, 0.0),
        ("c1_3", "1", 3, "Thợ săn hải tặc Roronoa Zoro (VIP)", "[\"https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900\"]", 1, 3000.0),
        ("c2_1", "2", 1, "Thợ săn yếu nhất cấp E", "[\"https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=900\"]", 0, 0.0)
    };
    foreach (var chapter in seedChapters)
    {
        await using var seed = db.CreateCommand();
        seed.CommandText = "INSERT OR IGNORE INTO chapters(id,manga_id,chapter_number,title,contents,created_at,updated_at,is_locked,is_deleted,price) VALUES($id,$manga,$number,$title,$contents,$now,$now,$locked,0,$price)";
        seed.Parameters.AddWithValue("$id", chapter.Item1);
        seed.Parameters.AddWithValue("$manga", chapter.Item2);
        seed.Parameters.AddWithValue("$number", chapter.Item3);
        seed.Parameters.AddWithValue("$title", chapter.Item4);
        seed.Parameters.AddWithValue("$contents", chapter.Item5);
        seed.Parameters.AddWithValue("$now", now);
        seed.Parameters.AddWithValue("$locked", chapter.Item6);
        seed.Parameters.AddWithValue("$price", chapter.Item7);
        await seed.ExecuteNonQueryAsync();
    }
}

static string? ValidateManga(MangaInput manga)
{
    if (string.IsNullOrWhiteSpace(manga.Title)) return "Tên truyện không được để trống.";
    if (string.IsNullOrWhiteSpace(manga.Author)) return "Tác giả không được để trống.";
    if (manga.TotalChapters < 0 || manga.CurrentChapter < 0 || manga.CurrentChapter > manga.TotalChapters) return "Số chapter không hợp lệ.";
    if (manga.Rating is < 0 or > 10) return "Điểm đánh giá phải từ 0 đến 10.";
    return null;
}

static void BindManga(SqliteCommand command, MangaInput manga, string id)
{
    command.Parameters.AddWithValue("$id", id);
    command.Parameters.AddWithValue("$title", manga.Title.Trim());
    command.Parameters.AddWithValue("$author", manga.Author.Trim());
    command.Parameters.AddWithValue("$description", manga.Description ?? "");
    command.Parameters.AddWithValue("$cover", manga.CoverUrl ?? "");
    command.Parameters.AddWithValue("$genre", manga.Genre ?? "Action");
    command.Parameters.AddWithValue("$status", manga.Status ?? "Ongoing");
    command.Parameters.AddWithValue("$total", manga.TotalChapters);
    command.Parameters.AddWithValue("$current", manga.CurrentChapter);
    command.Parameters.AddWithValue("$rating", manga.Rating);
    command.Parameters.AddWithValue("$favorite", manga.IsFavorite ? 1 : 0);
    command.Parameters.AddWithValue("$hidden", manga.IsHidden ? 1 : 0);
}

static object MangaDto(MangaInput m, string id) => new
{
    id, title = m.Title.Trim(), author = m.Author.Trim(), description = m.Description ?? "", coverUrl = m.CoverUrl ?? "",
    genre = m.Genre ?? "Action", status = m.Status ?? "Ongoing", totalChapters = m.TotalChapters,
    currentChapter = m.CurrentChapter, rating = m.Rating, isFavorite = m.IsFavorite, isHidden = m.IsHidden
};

static object ReadManga(SqliteDataReader r) => new
{
    id = r.GetString(0), title = r.GetString(1), author = r.GetString(2), description = r.GetString(3),
    coverUrl = r.GetString(4), genre = r.GetString(5), status = r.GetString(6), totalChapters = r.GetInt32(7),
    currentChapter = r.GetInt32(8), rating = r.GetDouble(9), isFavorite = r.GetInt32(10) != 0, isHidden = r.GetInt32(11) != 0
};

record GenreInput(string? Id, string? Name);
record MangaInput(string? Id, string Title, string Author, string? Description, string? CoverUrl, string? Genre, string? Status,
    int TotalChapters, int CurrentChapter, double Rating, bool IsFavorite, bool IsHidden);
record VisibilityInput(bool Hidden);
record FavoriteInput(bool IsFavorite);
record ProgressInput(int CurrentChapter);
