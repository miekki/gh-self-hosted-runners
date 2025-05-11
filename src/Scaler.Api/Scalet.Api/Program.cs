using System.Text.Json;
using System.Security.Cryptography;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add configuration sources in order of precedence
builder.Configuration
    // Base appsettings.json
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    // Environment-specific appsettings.json
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true)
    // Environment variables - highest precedence
    .AddEnvironmentVariables();

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

// Extract GitHub webhook secret from configuration
var webhookSecret = builder.Configuration["GitHubSecrets:WebhookSecret"];
if (string.IsNullOrEmpty(webhookSecret))
{
    Console.WriteLine("WARNING: GitHub webhook secret not configured. Webhook validation will be disabled.");
}

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();


app.MapPost("/webhook", async (HttpRequest request) =>
{
    try
    {
        // Enable buffering of the request body so it can be read multiple times
        request.EnableBuffering();

        // Validate GitHub webhook signature if secret is configured
        if (!string.IsNullOrEmpty(webhookSecret))
        {
            // Check for signature header
            if (!request.Headers.TryGetValue("X-Hub-Signature-256", out var signatureHeader))
            {
                return Results.Unauthorized();
            }

            // Extract signature value - should be in format "sha256=..."
            var providedSignature = signatureHeader.ToString();
            if (!providedSignature.StartsWith("sha256="))
            {
                return Results.Unauthorized();
            }

            // Read request body for validation
            using var bodyReader = new StreamReader(request.Body, leaveOpen: true);
            var rawBody = await bodyReader.ReadToEndAsync();

            // Calculate HMAC-SHA256 hash
            var secretBytes = Encoding.UTF8.GetBytes(webhookSecret);
            using var hmac = new HMACSHA256(secretBytes);
            var bodyBytes = Encoding.UTF8.GetBytes(rawBody);
            var hash = hmac.ComputeHash(bodyBytes);

            // Convert to hex string
            var computedSignature = "sha256=" + Convert.ToHexString(hash).ToLower();

            Console.WriteLine($"Provided Signature: {providedSignature}");
            Console.WriteLine($"Computed Signature: {computedSignature}");

            // Reset position to beginning of stream for later reading
            request.Body.Position = 0;

            // Compare signatures
            if (providedSignature != computedSignature)
            {
                Console.WriteLine("Signature mismatch. Unauthorized request.");
                return Results.Unauthorized();
            }
            Console.WriteLine("Signature match. Keep going.");
        }

        // If we reach here, the signature is valid or validation is disabled
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

        Console.WriteLine($"Webhook payload saved to {fileName}");

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

app.Run();



// record WebhookPayload(string? Action, string? Repository);