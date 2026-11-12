import { MigrationInterface, QueryRunner } from 'typeorm';

export class AuthSecurityHardening1700000000000
  implements MigrationInterface
{
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto;`);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS auth_audit (
        id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
        event       text NOT NULL,
        ip          inet,
        user_agent  text,
        created_at  timestamptz NOT NULL DEFAULT now()
      );
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS auth_audit_user_idx
        ON auth_audit (user_id, created_at DESC);
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS auth_audit_event_idx
        ON auth_audit (event, created_at DESC);
    `);
    await queryRunner.query(`
      ALTER TABLE auth_tokens
        ADD COLUMN IF NOT EXISTS attempt_count int NOT NULL DEFAULT 0;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE auth_tokens
        DROP COLUMN IF EXISTS attempt_count;
    `);
    await queryRunner.query(`DROP INDEX IF EXISTS auth_audit_event_idx;`);
    await queryRunner.query(`DROP INDEX IF EXISTS auth_audit_user_idx;`);
    await queryRunner.query(`DROP TABLE IF EXISTS auth_audit;`);
  }
}