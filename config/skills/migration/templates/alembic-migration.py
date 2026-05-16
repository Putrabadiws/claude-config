"""{{DESCRIPTION}}

Revision ID: {{REVISION_ID}}
Revises: {{PREVIOUS_REVISION}}
Create Date: {{DATE}}
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers
revision = "{{REVISION_ID}}"
down_revision = "{{PREVIOUS_REVISION}}"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Example: Create table
    op.create_table(
        "{{TABLE_NAME}}",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), onupdate=sa.func.now(), nullable=True),
        sa.Column("created_by", sa.UUID(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
    )

    # Example: Create index
    # op.create_index("idx_{{TABLE}}_{{COLUMN}}", "{{TABLE}}", ["{{COLUMN}}"])

    # Example: Add column
    # op.add_column("{{TABLE}}", sa.Column("{{COLUMN}}", sa.String(255), nullable=True))

    # Example: Add foreign key
    # op.create_foreign_key(
    #     "fk_{{TABLE}}_{{REF_TABLE}}",
    #     "{{TABLE}}",
    #     "{{REF_TABLE}}",
    #     ["{{COLUMN}}"],
    #     ["id"],
    # )


def downgrade() -> None:
    # Reverse operations in opposite order
    op.drop_table("{{TABLE_NAME}}")
