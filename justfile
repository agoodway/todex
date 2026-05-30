# Project automation recipes

# Start development server
up:
    mix run --no-halt

# Deploy to production
deploy:
    # TODO: Configure deployment

# Run tests
test:
    mix test

# Create the development database
db-create:
    mix ecto.create

# Run development database migrations
db-migrate:
    mix ecto.migrate

# Create and migrate the development database
db-setup:
    mix ecto.create
    mix ecto.migrate

# Drop, create, and migrate the development database
db-reset:
    mix ecto.drop
    mix ecto.create
    mix ecto.migrate

# Create and migrate the test database
db-test-setup:
    MIX_ENV=test mix ecto.create
    MIX_ENV=test mix ecto.migrate

# Drop, create, and migrate the test database
db-test-reset:
    MIX_ENV=test mix ecto.drop
    MIX_ENV=test mix ecto.create
    MIX_ENV=test mix ecto.migrate

# Run quality checks
check:
    mix compile --warnings-as-errors

# Compile the project
build:
    mix compile

# Clean build artifacts
clean:
    mix clean
    rm -rf _build deps
