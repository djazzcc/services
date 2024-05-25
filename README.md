# Djazz Services

Djazz Services is an all-in-one development framework for building web applications and APIs with Django.

To learn more about Djazz and how to use it, visit the [GitHub repository](https://github.com/azataiot/djazz).

## Why Djazz Services?

Unlike typical tutorials, Djazz is designed with production-readiness in mind. It leverages essential backend services such as PostgreSQL instead of SQLite, among others. While a simple Django project might suffice for learning purposes, real-world applications require a more robust setup involving components like Redis, Celery, RabbitMQ, and caching from the start.

Setting up such an environment can be time-consuming. Djazz Services aims to streamline this process by providing a comprehensive development environment with PostgreSQL and its essential extensions, Redis, RabbitMQ, and even tools for local email testing, all configured and ready to use.

With Djazz Services, you can focus on writing your Djazz code without worrying about the complexities of setting up and configuring the development environment.

## Included Services

- PostgreSQL
- Redis
- RabbitMQ
- Nginx
- pgAdmin
- Mailpit

## How to use

Using Djazz Services is easy, we assume you have already installed [Docker](https://docs.docker.com/) on your development computer or VM, and then you can start running Djazz Services by executing the following commands in your terminal: 

```bash
docker run --it azataiot/djazz-services -p 5432:5432 -p 
```

