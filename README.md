# HBTS_FINAL (Merged Project)

This folder consolidates all role-based apps and backend services into one structured workspace. Original sources remain in the root `mereged` directory; this is a reorganized, merged layout for day-to-day work.

## Roles
- Driver
- Conductor
- Customer
- Operator
- Admin

## Recommended Flow
1. Start backend API (core or driver API depending on the role).
2. Run the role app.
3. Use test credentials listed in `docs` as needed.

## Structure
- `apps/driver`: Driver apps (primary: `apps/driver/new_frontend`).
- `apps/conductor`: Placeholder for conductor-specific packaging (see `apps/multi_role/isalka`).
- `apps/customer`: Placeholder for customer-specific packaging (see `apps/multi_role/isalka`).
- `apps/operator`: Placeholder for operator-specific packaging (see `apps/multi_role/isalka`).
- `apps/admin`: Admin apps (primary: `apps/admin/repo_admin`).
- `apps/multi_role`: Full multi-role Flutter apps (Isalka, Mavindi, Minanga, Pasindu).
- `backend/driver_api`: Driver-focused APIs (primary: `backend/driver_api/new_backend`).
- `backend/core_api`: Core HBTS APIs (primary: `backend/core_api/repo_hbts_backend`).
- `docs`: Setup guides and references.
- `roles`: Role entry points and guidance.

## Role Entry Points
- Driver: `apps/driver/new_frontend`
- Conductor: `apps/multi_role/isalka`
- Customer: `apps/multi_role/isalka`
- Operator: `apps/multi_role/isalka` (operator dashboards) + `backend/core_api/repo_hbts_backend`
- Admin: `apps/admin/repo_admin`

## Backends
- Driver API: `backend/driver_api/new_backend`
- Core API: `backend/core_api/repo_hbts_backend`

## Notes
- Large generated folders are excluded during copy (`node_modules`, `build`, `.dart_tool`, `.git`).
- If you need a single role-only Flutter app later, we can split `apps/multi_role/isalka` into dedicated role apps.
