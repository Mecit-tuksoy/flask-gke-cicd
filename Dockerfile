# Multi-stage build for production
FROM python:3.10-slim as builder

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.10-slim

# Create non-root user
RUN groupadd -r flask && useradd -r -g flask flask

WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder /root/.local /home/flask/.local

# Copy application code
COPY app/ .

# Change ownership to flask user
RUN chown -R flask:flask /app

# Switch to non-root user
USER flask

# Update PATH to include user's local bin
ENV PATH=/home/flask/.local/bin:$PATH

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:5000', timeout=10)"

# Expose port
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]
