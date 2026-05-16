# TypeScript/Vitest Test Data Patterns

## Factory Pattern

```typescript
// fixtures/factories/user.factory.ts
import { v4 as uuid } from 'uuid';

interface UserOverrides {
  email?: string;
  role?: 'admin' | 'user' | 'viewer';
  active?: boolean;
}

export const UserFactory = {
  build(overrides: UserOverrides = {}) {
    return {
      id: uuid(),
      email: `test-${uuid()}@example.com`,
      role: 'user' as const,
      active: true,
      createdAt: new Date().toISOString(),
      ...overrides,
    };
  },

  async create(overrides: UserOverrides = {}, db: DB) {
    const data = this.build(overrides);
    await db.users.insert(data);
    return data;
  },

  async cleanup(id: string, db: DB) {
    await db.users.delete({ id });
  },
};
```

## Cleanup

Use `afterEach` or the factory's `cleanup` method:

```typescript
afterEach(async () => {
  await UserFactory.cleanup(userId, db);
});
```
