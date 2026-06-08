SHELL := /bin/bash

.PHONY: certs up down restart logs config clean test

certs:
	./scripts/generate-local-certs.sh

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d

logs:
	docker compose logs -f

config:
	docker compose config

test:
	./tests/validate_dashboard_queries.sh

clean:
	docker compose down -v
