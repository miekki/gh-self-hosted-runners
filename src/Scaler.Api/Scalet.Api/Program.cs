using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

var summaries = new[]
{
    "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
};

app.MapGet("/weatherforecast", () =>
{
    var forecast = Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            summaries[Random.Shared.Next(summaries.Length)]
        ))
        .ToArray();
    return forecast;
})
.WithName("GetWeatherForecast");
// ...existing code...

// Add this class at the bottom of the file


// Replace the existing webhook endpoint with this one
app.MapPost("/webhook", async (HttpRequest request) =>
{
    try
    {
        using var reader = new StreamReader(request.Body);
        var payload = await reader.ReadToEndAsync();

        // Parse the JSON payload into a JsonDocument first
        using JsonDocument document = JsonDocument.Parse(payload);

        // Create logs directory if it doesn't exist
        var logsDir = Path.Combine(Directory.GetCurrentDirectory(), "logs");
        Directory.CreateDirectory(logsDir);

        // Create unique filename with timestamp
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var fileName = Path.Combine(logsDir, $"webhook_{timestamp}_{Guid.NewGuid():N}.json");

        // Save payload with pretty formatting
        var jsonOptions = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };
        var formattedJson = JsonSerializer.Serialize(document.RootElement, jsonOptions);
        await File.WriteAllTextAsync(fileName, formattedJson);

        return Results.Ok(new { message = "Webhook received and saved", fileName });
        // var webhookData = JsonSerializer.Deserialize<WebhookPayload>(payload);

        // if (webhookData is null)
        // {
        //     return Results.BadRequest("Invalid payload");
        // }

        // return Results.Ok(new
        // {
        //     message = "Webhook received",
        //     action = webhookData.Action,
        //     repository = webhookData.Repository
        // });

    }
    catch (JsonException ex)
    {
        return Results.BadRequest($"Invalid JSON: {ex.Message}");
    }
});

// ...existing code...
// app.MapPost("/webhook", (string? name) =>
// {
//     return Results.Ok($"Hello {name}");
// });

app.Run();

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}


record WebhookPayload(string? Action, string? Repository);