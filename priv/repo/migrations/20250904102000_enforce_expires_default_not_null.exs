defmodule Shortnr.Repo.Migrations.EnforceExpiresDefaultNotNull do
  use Ecto.Migration

  def up do
    # Set NOT NULL and default on partitioned parent table
    execute "ALTER TABLE urls ALTER COLUMN expires_at SET NOT NULL"
    execute "ALTER TABLE urls ALTER COLUMN expires_at SET DEFAULT (now() + interval '48 hours')"
  end

  def down do
    # Remove NOT NULL and default (revert to nullable, no default)
    execute "ALTER TABLE urls ALTER COLUMN expires_at DROP NOT NULL"
    execute "ALTER TABLE urls ALTER COLUMN expires_at DROP DEFAULT"
  end
end
