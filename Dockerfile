FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies if needed (e.g., for compilation or curl)
# RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy requirements and install app dependencies (include OpenTelemetry dependencies)
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy source code
COPY . .

# Start the app (main.py inside "app/" directory)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]