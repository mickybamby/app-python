# Use an official Python base image
FROM python:3.10-slim
# Set working directory
WORKDIR /app
# Copy files into the container
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# Tell Docker how to start your app
CMD ["python", "app.py"]