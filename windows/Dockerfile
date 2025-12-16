# Dockerfile for running .NET Windows tests on macOS/Linux via Docker
# This allows testing business logic without needing a Windows environment

FROM mcr.microsoft.com/dotnet/sdk:8.0

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Restore dependencies
RUN dotnet restore Talkies.Windows.Tests/Talkies.Windows.Tests.csproj

# Default command runs the tests
CMD ["dotnet", "test", "Talkies.Windows.Tests/Talkies.Windows.Tests.csproj", "--logger", "trx", "--logger", "console;verbosity=detailed"]
