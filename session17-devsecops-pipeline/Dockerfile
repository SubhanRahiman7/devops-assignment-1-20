FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 HOST=0.0.0.0 PORT=5001

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Security fix: run as an unprivileged user instead of root
RUN useradd --system --uid 10001 appuser
USER appuser

EXPOSE 5001

HEALTHCHECK --interval=15s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5001/health')" || exit 1

CMD ["python", "app/app.py"]
