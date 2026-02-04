import { pool } from "../db.js";
import PDFDocument from "pdfkit";
import ExcelJS from "exceljs";

const formatDate = (value) => {
  if (!value) return "";
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  const y = d.getFullYear().toString().padStart(4, "0");
  const m = (d.getMonth() + 1).toString().padStart(2, "0");
  const day = d.getDate().toString().padStart(2, "0");
  return `${y}-${m}-${day}`;
};

const formatDateTime = (value) => {
  if (!value) return "";
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return value?.toString?.() ?? "";
  const y = d.getFullYear().toString().padStart(4, "0");
  const m = (d.getMonth() + 1).toString().padStart(2, "0");
  const day = d.getDate().toString().padStart(2, "0");
  const h = d.getHours().toString().padStart(2, "0");
  const min = d.getMinutes().toString().padStart(2, "0");
  return `${y}-${m}-${day} ${h}:${min}`;
};

const defaultRange = () => {
  const to = new Date();
  const from = new Date(to);
  from.setDate(to.getDate() - 30);
  return { from: formatDate(from), to: formatDate(to) };
};

const tableCache = new Map();

const getColumns = async (tableName) => {
  if (tableCache.has(tableName)) return tableCache.get(tableName);
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = $1
    `,
    [tableName]
  );
  const columns = rows.map((r) => r.column_name);
  tableCache.set(tableName, columns);
  return columns;
};

const pickColumn = (columns, candidates) =>
  candidates.find((c) => columns.includes(c));

const buildReportData = async ({ from, to }) => {
  const range = defaultRange();
  const fromDate = formatDate(from) || range.from;
  const toDate = formatDate(to) || range.to;

  const [{ rows: passengerTotals }] = await Promise.all([
    pool.query(
      `
      SELECT
        COUNT(*)::int AS total_passengers,
        COUNT(*) FILTER (
          WHERE u.created_at::date BETWEEN $1::date AND $2::date
        )::int AS new_passengers
      FROM users u
      JOIN roles r ON u.role_id = r.role_id
      WHERE r.role_name = 'passenger'
        AND u.deleted_at IS NULL
      `,
      [fromDate, toDate]
    ),
  ]);

  const tripsStatus = await pool.query(
    `
    SELECT t.status::text AS status, COUNT(*)::int AS total
    FROM trips t
    WHERE t.trip_date::date BETWEEN $1::date AND $2::date
    GROUP BY t.status
    `,
    [fromDate, toDate]
  );

  const tripsTotal = await pool.query(
    `
    SELECT COUNT(*)::int AS total
    FROM trips t
    WHERE t.trip_date::date BETWEEN $1::date AND $2::date
    `,
    [fromDate, toDate]
  );

  const driverColumns = await getColumns("drivers");
  const routeColumns = await getColumns("routes");
  const busColumns = await getColumns("buses");

  const driverNameCol = pickColumn(driverColumns, [
    "name",
    "full_name",
    "driver_name",
    "fullName",
    "driverName",
  ]);
  const routeNameCol = pickColumn(routeColumns, [
    "route_name",
    "name",
    "routeName",
  ]);
  const routeCodeCol = pickColumn(routeColumns, [
    "route_no",
    "route_code",
    "route_number",
    "code",
  ]);
  const busPlateCol = pickColumn(busColumns, [
    "license_plate_no",
    "license_plate",
  ]);

  const selectExtras = [
    driverNameCol
      ? `d."${driverNameCol}" AS driver_name`
      : "NULL AS driver_name",
    routeNameCol
      ? `r."${routeNameCol}" AS route_name`
      : "NULL AS route_name",
    routeCodeCol
      ? `r."${routeCodeCol}" AS route_code`
      : "NULL AS route_code",
    busPlateCol
      ? `b."${busPlateCol}" AS license_plate_no`
      : "NULL AS license_plate_no",
  ];

  const tripsList = await pool.query(
    `
    SELECT t.*, ${selectExtras.join(", ")}
    FROM trips t
    LEFT JOIN routes r ON r.route_id = t.route_id
    LEFT JOIN buses b ON b.bus_id = t.bus_id
    LEFT JOIN drivers d ON d.driver_id = t.driver_id
    WHERE t.trip_date::date BETWEEN $1::date AND $2::date
    ORDER BY t.trip_date DESC, t.trip_id DESC
    `,
    [fromDate, toDate]
  );

  const statusTotals = tripsStatus.rows.reduce((acc, row) => {
    const key = (row.status ?? "").toLowerCase();
    acc[key] = row.total ?? 0;
    return acc;
  }, {});

  return {
    range: { from: fromDate, to: toDate },
    summary: {
      passengers_total: passengerTotals[0]?.total_passengers ?? 0,
      passengers_new: passengerTotals[0]?.new_passengers ?? 0,
      trips_total: tripsTotal.rows[0]?.total ?? 0,
      trips_scheduled: statusTotals.scheduled ?? 0,
      trips_in_progress: statusTotals.in_progress ?? 0,
      trips_completed: statusTotals.completed ?? 0,
      trips_cancelled: statusTotals.cancelled ?? 0,
    },
    trips: tripsList.rows ?? [],
  };
};

export const driverStatusReport = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT status, COUNT(*) AS total
      FROM drivers
      GROUP BY status
    `);

    res.json(result.rows);
  } catch (error) {
    console.error("Driver status report error:", error);
    res.status(500).json({ message: "Failed to generate report" });
  }
};

export const reportSummary = async (req, res) => {
  try {
    const data = await buildReportData({
      from: req.query.from,
      to: req.query.to,
    });
    res.json(data);
  } catch (error) {
    console.error("Summary report error:", error);
    res.status(500).json({ message: "Failed to generate report" });
  }
};

export const reportSummaryPdf = async (req, res) => {
  try {
    const data = await buildReportData({
      from: req.query.from,
      to: req.query.to,
    });

    const doc = new PDFDocument({ margin: 40, size: "A4" });
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="report-summary-${data.range.from}-to-${data.range.to}.pdf"`
    );

    doc.pipe(res);
    doc.font("Helvetica-Bold").fontSize(18).text("HBTS Report Summary", {
      align: "left",
    });
    doc.moveDown(0.5);
    doc.font("Helvetica").fontSize(12).text(
      `Date Range: ${data.range.from} to ${data.range.to}`
    );

    doc.moveDown();
    doc.font("Helvetica-Bold").fontSize(14).text("Summary");
    doc.moveDown(0.3);
    doc.font("Helvetica").fontSize(11);
    doc.text(`Total Passengers: ${data.summary.passengers_total}`);
    doc.text(`New Passengers: ${data.summary.passengers_new}`);
    doc.text(`Total Trips: ${data.summary.trips_total}`);
    doc.text(`Scheduled Trips: ${data.summary.trips_scheduled}`);
    doc.text(`In Progress Trips: ${data.summary.trips_in_progress}`);
    doc.text(`Completed Trips: ${data.summary.trips_completed}`);
    doc.text(`Cancelled Trips: ${data.summary.trips_cancelled}`);

    doc.moveDown();
    doc.font("Helvetica-Bold").fontSize(14).text("Trips");
    doc.moveDown(0.5);

    const rows = data.trips.slice(0, 500);
    const left = doc.page.margins.left;
    const right = doc.page.margins.right;
    const pageWidth = doc.page.width - left - right;

    const columns = [
      { header: "Trip ID", width: 55, key: "trip_id" },
      { header: "Route", width: 135, key: "route_name" },
      { header: "Bus", width: 85, key: "license_plate_no" },
      { header: "Driver", width: 120, key: "driver_name" },
      { header: "Date", width: 80, key: "trip_date" },
      { header: "Status", width: 70, key: "status" },
    ];

    const totalWidth = columns.reduce((sum, c) => sum + c.width, 0);
    if (totalWidth < pageWidth) {
      const extra = pageWidth - totalWidth;
      columns[1].width += extra;
    }

    const rowHeight = 16;

    const drawHeader = (y) => {
      let x = left;
      doc.font("Helvetica-Bold").fontSize(9);
      columns.forEach((col) => {
        doc.text(col.header, x, y, { width: col.width });
        x += col.width;
      });
      doc.moveTo(left, y + rowHeight - 2)
        .lineTo(left + pageWidth, y + rowHeight - 2)
        .strokeColor("#cccccc")
        .stroke();
    };

    let y = doc.y;
    drawHeader(y);
    y += rowHeight;

    doc.font("Helvetica").fontSize(9);
    for (const trip of rows) {
      if (y + rowHeight > doc.page.height - doc.page.margins.bottom) {
        doc.addPage();
        y = doc.y;
        drawHeader(y);
        y += rowHeight;
        doc.font("Helvetica").fontSize(9);
      }

      let x = left;
      const values = [
        trip.trip_id ?? "-",
        trip.route_name ?? trip.route_code ?? "-",
        trip.license_plate_no ?? "-",
        trip.driver_name ?? "-",
        formatDate(trip.trip_date),
        trip.status ?? "-",
      ];
      values.forEach((value, idx) => {
        doc.text(value?.toString?.() ?? "-", x, y, {
          width: columns[idx].width,
        });
        x += columns[idx].width;
      });
      y += rowHeight;
    }

    doc.end();
  } catch (error) {
    console.error("Summary PDF error:", error);
    res.status(500).json({ message: "Failed to generate PDF report" });
  }
};

export const reportSummaryExcel = async (req, res) => {
  try {
    const data = await buildReportData({
      from: req.query.from,
      to: req.query.to,
    });

    const workbook = new ExcelJS.Workbook();
    const summarySheet = workbook.addWorksheet("Summary");
    summarySheet.columns = [
      { width: 28 },
      { width: 18 },
    ];
    summarySheet.mergeCells("A1:B1");
    summarySheet.getCell("A1").value = "HBTS Report Summary";
    summarySheet.getCell("A1").font = { size: 14, bold: true };
    summarySheet.mergeCells("A2:B2");
    summarySheet.getCell("A2").value =
      `Date Range: ${data.range.from} to ${data.range.to}`;
    summarySheet.getCell("A2").font = { italic: true };
    summarySheet.addRow([]);
    summarySheet.addRow(["Total Passengers", data.summary.passengers_total]);
    summarySheet.addRow(["New Passengers", data.summary.passengers_new]);
    summarySheet.addRow(["Total Trips", data.summary.trips_total]);
    summarySheet.addRow(["Scheduled Trips", data.summary.trips_scheduled]);
    summarySheet.addRow(["In Progress Trips", data.summary.trips_in_progress]);
    summarySheet.addRow(["Completed Trips", data.summary.trips_completed]);
    summarySheet.addRow(["Cancelled Trips", data.summary.trips_cancelled]);

    const tripsSheet = workbook.addWorksheet("Trips");
    tripsSheet.columns = [
      { header: "Trip ID", key: "trip_id", width: 10 },
      { header: "Route", key: "route", width: 24 },
      { header: "Route Code", key: "route_code", width: 14 },
      { header: "Bus", key: "bus", width: 14 },
      { header: "Driver", key: "driver", width: 22 },
      { header: "Trip Date", key: "trip_date", width: 12 },
      { header: "Departure", key: "departure", width: 18 },
      { header: "Arrival", key: "arrival", width: 18 },
      { header: "Status", key: "status", width: 12 },
    ];

    const headerRow = tripsSheet.getRow(1);
    headerRow.font = { bold: true };
    headerRow.alignment = { vertical: "middle", horizontal: "center" };
    headerRow.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: "FFEFEFEF" },
    };
    tripsSheet.views = [{ state: "frozen", ySplit: 1 }];

    data.trips.forEach((trip) => {
      tripsSheet.addRow({
        trip_id: trip.trip_id ?? "",
        route: trip.route_name ?? "",
        route_code: trip.route_code ?? "",
        bus: trip.license_plate_no ?? "",
        driver: trip.driver_name ?? "",
        trip_date: formatDate(trip.trip_date),
        departure: formatDateTime(trip.departure_time),
        arrival: formatDateTime(trip.arrival_time),
        status: trip.status ?? "",
      });
    });

    tripsSheet.eachRow((row, rowNumber) => {
      row.alignment = { vertical: "middle", horizontal: "left" };
      row.eachCell((cell) => {
        cell.border = {
          top: { style: "thin", color: { argb: "FFE0E0E0" } },
          left: { style: "thin", color: { argb: "FFE0E0E0" } },
          bottom: { style: "thin", color: { argb: "FFE0E0E0" } },
          right: { style: "thin", color: { argb: "FFE0E0E0" } },
        };
        if (rowNumber === 1) {
          cell.alignment = { vertical: "middle", horizontal: "center" };
        }
      });
    });

    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    );
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="report-summary-${data.range.from}-to-${data.range.to}.xlsx"`
    );

    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    console.error("Summary Excel error:", error);
    res.status(500).json({ message: "Failed to generate Excel report" });
  }
};
