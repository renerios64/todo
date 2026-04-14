# ── Stage 1: Build ──────────────────────────────────────────────────────────
# Use the full .NET SDK image — we need the compiler here
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy the project file first and restore dependencies.
# This layer is cached — Docker only re-runs restore if .csproj changes,
# not every time source code changes. Big time saver on rebuilds.
COPY ServiceRequestApi.csproj .
RUN dotnet restore

# Now copy all source code and publish a release build.
# "publish" compiles + bundles everything needed to run the app.
COPY . .
RUN dotnet publish -c Release -o /app/publish

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
# Switch to a much smaller image — just the ASP.NET runtime, no SDK
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Copy only the published output from the build stage.
# Source code, SDK tools, and intermediate files are left behind entirely.
COPY --from=build /app/publish .

# The app listens on port 8080 inside the container.
# (ASP.NET Core 8+ defaults to 8080 in containers)
EXPOSE 8080

ENTRYPOINT ["dotnet", "ServiceRequestApi.dll"]
