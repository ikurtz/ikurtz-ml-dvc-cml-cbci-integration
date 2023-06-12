FROM python:3

RUN apt-get update && \
    apt-get install -y python3-venv && \
    rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]

