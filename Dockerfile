FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install test dependencies
RUN pip install --no-cache-dir pytest

COPY . .

RUN chmod +x run-test.sh

CMD ["python", "app.py"]
