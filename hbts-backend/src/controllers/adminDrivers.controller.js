import { pool } from "../db.js";

const allowedStatuses = ["approved", "pending", "rejected"];
const driverStatusMap = {
  approved: "active",
  pending: "inactive",
  rejected: "suspended",
};
const driverStatusInverseMap = {
  active: "approved",
  inactive: "pending",
  suspended: "rejected",
};

let cachedDriverColumns = null;
const getDriverColumns = async () => {
  if (cachedDriverColumns) return cachedDriverColumns;
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'drivers'
    `
  );
  cachedDriverColumns = rows.map((r) => r.column_name);
  return cachedDriverColumns;
};

let cachedTempDriverColumns = null;
const getTempDriverColumns = async () => {
  if (cachedTempDriverColumns) return cachedTempDriverColumns;
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'temp_drivers'
    `
  );
  cachedTempDriverColumns = rows.map((r) => r.column_name);
  return cachedTempDriverColumns;
};

const pickColumn = (columns, candidates) =>
  candidates.firstWhere?.((c) => columns.includes(c)) ??
  candidates.find((c) => columns.includes(c));

const getIdColumn = (columns) =>
  pickColumn(columns, [
    "driver_id",
    "id",
    "driverId",
    "driverid",
    "id_driver",
    "temp_driver_id",
    "temp_id",
  ]);

const getUserIdValue = (row) =>
  row.user_id ?? row.userId ?? row.userid ?? row.user_id_ref ?? row.user;

const getDriverRefValue = (row) =>
  row.drivername ??
  row.driver_name ??
  row.driverName ??
  row.driver_name_ref ??
  getUserIdValue(row);

const getOperatorIdValue = (row) =>
  row.operator_id ?? row.operatorId ?? row.operatorid ?? row.company_id ?? row.companyId;

const resolveDriverStatusValue = async (status) => {
  if (!status) return status;
  const s = status.toLowerCase();

  // Map high-level statuses into drivers table constraint values
  if (driverStatusMap[s]) return driverStatusMap[s];

  // Otherwise, try to reuse any existing stored status (for enums/custom casing)
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT status FROM drivers WHERE status IS NOT NULL LIMIT 20`
    );
    const found = rows
      .map((r) => r.status)
      .find((v) => v && v.toString().toLowerCase() === s);
    if (found) return found;
  } catch (e) {
    // ignore and fall back
  }

  // Fallback: return lowercase to satisfy most check constraints
  return s;
};

const normDriver = (row, source = "drivers") => ({
  driver_id:
    row.driver_id ??
    row.id ??
    row.driverId ??
    row.driverid ??
    row.id_driver ??
    row.temp_driver_id ??
    row.temp_id,
  name:
    row.name ??
    row.full_name ??
    row.driver_name ??
    row.fullName ??
    row.driverName ??
    row.drivername,
  license_number: row.license_number ?? row.license ?? row.license_no,
  phone: row.phone ?? row.phone_number ?? row.mobile ?? row.mobile_number,
  operator_name:
    row.operator ??
    row.operator_name ??
    row.operatorName ??
    row.operatorname ??
    row.company,
  status:
    source === "drivers"
      ? driverStatusInverseMap[row.status?.toLowerCase()] ?? row.status
      : row.status,
  rejection_reason: row.rejection_reason ?? row.reason ?? row.rejectionReason,
  created_at: row.created_at ?? row.createdAt,
  updated_at: row.updated_at ?? row.updatedAt,
  drivername: getDriverRefValue(row),
  user_id: getUserIdValue(row),
  operator_id: getOperatorIdValue(row),
  source,
});

const findTempDriverById = async (id) => {
  const columns = await getTempDriverColumns();
  if (!columns.length) return null;

  const idCol = getIdColumn(columns);
  if (!idCol) return null;

  const { rows } = await pool.query(
    `SELECT * FROM temp_drivers WHERE "${idCol}" = $1 LIMIT 1`,
    [id]
  );

  if (!rows.length) return null;

  return { row: rows[0], columns, idCol };
};

const updateRecordFields = async ({ tableName, columns, id, body }) => {
  if (!columns?.length) return null;

  const idCol = getIdColumn(columns);
  if (!idCol) return null;

  const existing = await pool.query(
    `SELECT * FROM ${tableName} WHERE "${idCol}" = $1 LIMIT 1`,
    [id]
  );

  if (!existing.rows.length) return null;

  const { fullName, licenseNumber, phone, operatorName } = body;

  const updates = [];
  const params = [];

  const nameCol = pickColumn(columns, [
    "name",
    "full_name",
    "driver_name",
    "drivername",
    "fullName",
    "driverName",
  ]);
  const licenseCol = pickColumn(columns, [
    "license_number",
    "license",
    "license_no",
  ]);
  const phoneCol = pickColumn(columns, [
    "phone",
    "phone_number",
    "mobile",
    "mobile_number",
  ]);
  const operatorCol = pickColumn(columns, [
    "operator",
    "operator_name",
    "operatorname",
    "company",
  ]);

  if (fullName && nameCol) {
    updates.push(`"${nameCol}" = $${updates.length + 1}`);
    params.push(fullName);
  }
  if (licenseNumber && licenseCol) {
    updates.push(`"${licenseCol}" = $${updates.length + 1}`);
    params.push(licenseNumber);
  }
  if (phone && phoneCol) {
    updates.push(`"${phoneCol}" = $${updates.length + 1}`);
    params.push(phone);
  }
  if (operatorName && operatorCol) {
    updates.push(`"${operatorCol}" = $${updates.length + 1}`);
    params.push(operatorName);
  }

  if (updates.length === 0) {
    return existing.rows[0];
  }

  const hasUpdatedAt = columns.includes("updated_at");
  const setSql = hasUpdatedAt
    ? `${updates.join(", ")}, updated_at = now()`
    : updates.join(", ");

  const result = await pool.query(
    `
    UPDATE ${tableName}
    SET ${setSql}
    WHERE "${idCol}" = $${params.length + 1}
    RETURNING *
    `,
    [...params, id]
  );

  if (!result.rows.length) {
    return existing.rows[0];
  }

  return result.rows[0];
};

const updateStatusRow = async ({
  tableName,
  columns,
  idCol,
  id,
  newStatus,
  reason,
}) => {
  if (!columns?.length || !idCol) return null;

  const statusCol = pickColumn(columns, ["status"]);
  if (!statusCol) return null;

  const reasonCol = pickColumn(columns, ["rejection_reason", "reason"]);
  const statusValue =
    tableName === "drivers"
      ? await resolveDriverStatusValue(newStatus)
      : newStatus;
  const updates = [`"${statusCol}" = $1`];
  const params = [statusValue];

  if (reasonCol) {
    updates.push(`"${reasonCol}" = $${updates.length + 1}`);
    params.push(newStatus === "rejected" ? reason ?? null : null);
  }

  if (columns.includes("updated_at")) {
    updates.push("updated_at = now()");
  }

  params.push(id);

  const { rows } = await pool.query(
    `
    UPDATE ${tableName}
    SET ${updates.join(", ")}
    WHERE "${idCol}" = $${params.length}
    RETURNING *
    `,
    params
  );

  return rows[0] ?? null;
};

const insertDriverFromTemp = async ({ tempRow, driverColumns, newStatus, reason }) => {
  if (!driverColumns?.length) return null;

  const normalized = normDriver(tempRow, "temp");
  const driverStatusValue = await resolveDriverStatusValue(newStatus);
  const cols = [];
  const placeholders = [];
  const params = [];

  const driverRefCol = pickColumn(driverColumns, [
    "drivername",
    "user_id",
    "userId",
    "userid",
  ]);
  const tempRefValue = getDriverRefValue(tempRow) ?? normalized.name;
  if (driverRefCol) {
    if (!tempRefValue) {
      throw new Error("Missing driver reference for insert");
    }

    // If a driver already exists for this reference, update that record instead of inserting
    const idCol = getIdColumn(driverColumns) ?? "driver_id";
    const existingDriver = await pool.query(
      `SELECT * FROM drivers WHERE "${driverRefCol}" = $1 LIMIT 1`,
      [tempRefValue]
    );
    if (existingDriver.rows.length) {
      const existingId = existingDriver.rows[0][idCol];

      // Update status to newStatus (mapped internally)
      const statusUpdated = await updateStatusRow({
        tableName: "drivers",
        columns: driverColumns,
        idCol,
        id: existingId,
        newStatus,
        reason,
      });

      // Update profile fields from temp data
      const fieldsUpdated = await updateRecordFields({
        tableName: "drivers",
        columns: driverColumns,
        id: existingId,
        body: {
          fullName: normalized.name,
          licenseNumber: normalized.license_number,
          phone: normalized.phone,
          operatorName: normalized.operator_name,
        },
      });

      return fieldsUpdated ?? statusUpdated ?? existingDriver.rows[0];
    }

    cols.push(`"${driverRefCol}"`);
    params.push(tempRefValue);
    placeholders.push(`$${params.length}`);
  }

  const driverOperatorIdCol = pickColumn(driverColumns, [
    "operator_id",
    "operatorId",
    "operatorid",
    "company_id",
  ]);
  const tempOperatorId = getOperatorIdValue(tempRow);
  if (driverOperatorIdCol) {
    if (!tempOperatorId) {
      throw new Error("Missing operator_id for driver insert");
    }
    cols.push(`"${driverOperatorIdCol}"`);
    params.push(tempOperatorId);
    placeholders.push(`$${params.length}`);
  }

  const addParam = (col, value) => {
    if (!col) return;
    if (cols.includes(`"${col}"`)) return;
    cols.push(`"${col}"`);
    params.push(value ?? null);
    placeholders.push(`$${params.length}`);
  };

  addParam(
    pickColumn(driverColumns, [
      "name",
      "full_name",
      "driver_name",
      "drivername",
      "fullName",
      "driverName",
    ]),
    normalized.name
  );
  addParam(
    pickColumn(driverColumns, ["license_number", "license", "license_no"]),
    normalized.license_number
  );
  addParam(
    pickColumn(driverColumns, ["phone", "phone_number", "mobile", "mobile_number"]),
    normalized.phone
  );
  addParam(
    pickColumn(driverColumns, ["operator", "operator_name", "operatorname", "company"]),
    normalized.operator_name
  );

  const statusCol = pickColumn(driverColumns, ["status"]);
  if (statusCol) addParam(statusCol, driverStatusValue);

  const reasonCol = pickColumn(driverColumns, ["rejection_reason", "reason"]);
  if (reasonCol) {
    addParam(reasonCol, newStatus === "rejected" ? reason ?? null : null);
  }

  if (driverColumns.includes("created_at")) {
    cols.push(`"created_at"`);
    placeholders.push("now()");
  }

  if (driverColumns.includes("updated_at")) {
    cols.push(`"updated_at"`);
    placeholders.push("now()");
  }

  if (!cols.length) return null;

  const { rows } = await pool.query(
    `
    INSERT INTO drivers (${cols.join(", ")})
    VALUES (${placeholders.join(", ")})
    RETURNING *
    `,
    params
  );

  return rows[0] ?? null;
};

const updateTempStatus = async ({ columns, idCol, id, newStatus, reason }) => {
  if (!columns?.length || !idCol) return null;

  const statusCol = pickColumn(columns, ["status"]);
  if (!statusCol) return null;
  const reasonCol = pickColumn(columns, ["rejection_reason", "reason"]);
  const updates = [`"${statusCol}" = $1`];
  const params = [newStatus];

  if (reasonCol) {
    updates.push(`"${reasonCol}" = $${updates.length + 1}`);
    params.push(newStatus === "rejected" ? reason ?? null : null);
  }

  if (columns.includes("updated_at")) {
    updates.push("updated_at = now()");
  }

  if (!updates.length) return null;

  params.push(id);

  const { rows } = await pool.query(
    `
    UPDATE temp_drivers
    SET ${updates.join(", ")}
    WHERE "${idCol}" = $${params.length}
    RETURNING *
    `,
    params
  );

  return rows[0] ?? null;
};

export const listDrivers = async (req, res) => {
  try {
    const { status, search = "" } = req.query;
    const statusFilter = status?.toLowerCase();
    const results = [];

    // 1) Drivers table (approved/rejected, and pending if stored there)
    const driverColumns = await getDriverColumns();
    if (driverColumns.length) {
      const driverConditions = [];
      const driverParams = [];

      const driverStatusCol = pickColumn(driverColumns, ["status"]);
      if (statusFilter && driverStatusCol) {
        const mappedStatus = driverStatusMap[statusFilter] ?? statusFilter;
        driverConditions.push(
          `LOWER(d."${driverStatusCol}") = $${driverConditions.length + 1}`
        );
        driverParams.push(mappedStatus.toLowerCase());
      }

      const driverNameCol = pickColumn(driverColumns, [
        "name",
        "full_name",
        "driver_name",
        "drivername",
        "fullName",
        "driverName",
      ]);

      if (search && driverNameCol) {
        driverConditions.push(
          `(LOWER(d."${driverNameCol}") LIKE LOWER($${driverConditions.length + 1}))`
        );
        driverParams.push(`%${search}%`);
      }

      const driverWhere = driverConditions.length
        ? ` WHERE ${driverConditions.join(" AND ")}`
        : "";

      const driverUserIdCol = pickColumn(driverColumns, [
        "user_id",
        "userId",
        "userid",
      ]);
      const driverJoin = driverUserIdCol
        ? ` LEFT JOIN users u ON u.user_id = d."${driverUserIdCol}"`
        : "";
      const driverSelect = driverUserIdCol
        ? `SELECT d.*, u.name AS user_name, u.email AS user_email, u.phone AS user_phone`
        : "SELECT d.*";

      const driverIdCol = getIdColumn(driverColumns) ?? "driver_id";
      const driverOrderBy = driverColumns.includes("created_at")
        ? `d."created_at"`
        : `d."${driverIdCol}"`;

      const driverResult = await pool.query(
        `${driverSelect} FROM drivers d${driverJoin}${driverWhere} ORDER BY ${driverOrderBy} DESC`,
        driverParams
      );

      results.push(...driverResult.rows.map((r) => normDriver(r, "drivers")));
    }

    // 2) temp_drivers table (pending applications that haven't been promoted yet)
    const shouldIncludeTemp =
      !statusFilter ||
      statusFilter === "pending" ||
      statusFilter === "rejected" ||
      statusFilter === "approved";
    if (shouldIncludeTemp) {
      const tempColumns = await getTempDriverColumns();
      if (tempColumns.length) {
        const tempConditions = [];
        const tempParams = [];

        const tempStatusCol = pickColumn(tempColumns, ["status"]);
        const tempNameCol = pickColumn(tempColumns, [
          "name",
          "full_name",
          "driver_name",
          "drivername",
          "fullName",
          "driverName",
        ]);

        const targetStatus = statusFilter ?? "pending";
        if (tempStatusCol) {
          tempConditions.push(
            `LOWER("${tempStatusCol}") = $${tempConditions.length + 1}`
          );
          tempParams.push(targetStatus);
        }

        if (search && tempNameCol) {
          tempConditions.push(
            `(LOWER("${tempNameCol}") LIKE LOWER($${tempConditions.length + 1}))`
          );
          tempParams.push(`%${search}%`);
        }

        const tempWhere = tempConditions.length
          ? ` WHERE ${tempConditions.join(" AND ")}`
          : "";

        const tempIdCol = getIdColumn(tempColumns);
        const tempOrderBy = tempColumns.includes("created_at")
          ? `"created_at"`
          : tempIdCol
            ? `"${tempIdCol}"`
            : null;
        const tempOrderClause = tempOrderBy ? ` ORDER BY ${tempOrderBy} DESC` : "";

        const tempResult = await pool.query(
          `SELECT * FROM temp_drivers${tempWhere}${tempOrderClause}`,
          tempParams
        );

        results.push(...tempResult.rows.map((r) => normDriver(r, "temp")));
      }
    }

    res.json(results);
  } catch (err) {
    console.error("List drivers error:", err);
    res.status(500).json({ message: "Failed to load drivers" });
  }
};

export const getDriverById = async (req, res) => {
  try {
    const { id } = req.params;

    const driverColumns = await getDriverColumns();
    const driverIdCol = getIdColumn(driverColumns) ?? "driver_id";
    const driverUserIdCol = pickColumn(driverColumns, [
      "user_id",
      "userId",
      "userid",
    ]);

    if (driverColumns.length) {
      const driverJoin = driverUserIdCol
        ? ` LEFT JOIN users u ON u.user_id = d."${driverUserIdCol}"`
        : "";
      const driverSelect = driverUserIdCol
        ? `SELECT d.*, u.name AS user_name, u.email AS user_email, u.phone AS user_phone`
        : "SELECT d.*";
      const result = await pool.query(
        `${driverSelect} FROM drivers d${driverJoin} WHERE d."${driverIdCol}" = $1 LIMIT 1`,
        [id]
      );

      if (result.rows.length) {
        return res.json(normDriver(result.rows[0], "drivers"));
      }
    }

    const tempDriver = await findTempDriverById(id);
    if (tempDriver?.row) {
      return res.json(normDriver(tempDriver.row, "temp"));
    }

    return res.status(404).json({ message: "Driver not found" });
  } catch (err) {
    console.error("Get driver error:", err);
    res.status(500).json({ message: "Failed to load driver" });
  }
};

export const updateDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const driverColumns = await getDriverColumns();
    const updatedDriver = await updateRecordFields({
      tableName: "drivers",
      columns: driverColumns,
      id,
      body: req.body,
    });

    if (updatedDriver) {
      return res.json(normDriver(updatedDriver, "drivers"));
    }

    const tempDriver = await findTempDriverById(id);
    if (tempDriver) {
      const updatedTemp = await updateRecordFields({
        tableName: "temp_drivers",
        columns: tempDriver.columns,
        id,
        body: req.body,
      });

      if (updatedTemp) {
        return res.json(normDriver(updatedTemp, "temp"));
      }
    }

    return res.status(404).json({ message: "Driver not found" });
  } catch (err) {
    console.error("Update driver error:", err);
    res.status(500).json({ message: "Failed to update driver" });
  }
};

export const updateDriverStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, reason } = req.body;

    if (!status || !allowedStatuses.includes(status.toLowerCase())) {
      return res
        .status(400)
        .json({ message: "Status must be approved, pending or rejected" });
    }

    const newStatus = status.toLowerCase();
    const driverColumns = await getDriverColumns();
    const driverIdCol = getIdColumn(driverColumns);

    // 1) Try updating an existing driver record
    if (driverColumns.length && driverIdCol) {
      const existingDriver = await pool.query(
        `SELECT * FROM drivers WHERE "${driverIdCol}" = $1 LIMIT 1`,
        [id]
      );

      if (existingDriver.rows.length) {
        const updated = await updateStatusRow({
          tableName: "drivers",
          columns: driverColumns,
          idCol: driverIdCol,
          id,
          newStatus,
          reason,
        });

        if (!updated) {
          return res
            .status(400)
            .json({ message: "Status column not found in drivers table" });
        }

        return res.json(normDriver(updated, "drivers"));
      }
    }

    // 2) If not in drivers, look for a temp driver (pending applications)
    const tempDriver = await findTempDriverById(id);
    if (!tempDriver) {
      return res.status(404).json({ message: "Driver not found" });
    }

    // Approving a temp driver: promote into drivers table then mark temp as approved
    if (newStatus === "approved") {
      const driverColumnsForInsert = driverColumns.length
        ? driverColumns
        : await getDriverColumns();

      if (!driverColumnsForInsert.length) {
        return res
          .status(500)
          .json({ message: "Drivers table is not configured for approvals" });
      }

      const driversStatusCol = pickColumn(driverColumnsForInsert, ["status"]);
      if (!driversStatusCol) {
        return res
          .status(400)
          .json({ message: "Status column not found in drivers table" });
      }

      const inserted = await insertDriverFromTemp({
        tempRow: tempDriver.row,
        driverColumns: driverColumnsForInsert,
        newStatus,
        reason,
      });

      const updatedTemp = await updateTempStatus({
        columns: tempDriver.columns,
        idCol: tempDriver.idCol,
        id,
        newStatus,
        reason,
      });

      if (!updatedTemp) {
        return res
          .status(400)
          .json({ message: "Status column not found in temp_drivers table" });
      }

      return res.json(inserted ? normDriver(inserted, "drivers") : normDriver(updatedTemp, "temp"));
    }

    // Reject or set back to pending inside temp_drivers
    const updatedTemp = await updateTempStatus({
      columns: tempDriver.columns,
      idCol: tempDriver.idCol,
      id,
      newStatus,
      reason,
    });

    if (!updatedTemp) {
      return res
        .status(400)
        .json({ message: "Status column not found in temp_drivers table" });
    }

    return res.json(normDriver(updatedTemp, "temp"));
  } catch (err) {
  if (
    err?.message?.includes("Missing driver reference") ||
    err?.message?.includes("Missing operator_id")
  ) {
      return res.status(400).json({ message: err.message });
    }
    console.error("Update driver status error:", err);
    res.status(500).json({ message: "Failed to update driver status" });
  }
};
