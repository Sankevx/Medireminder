require('dotenv').config();
const express = require('express'), cors = require('cors'), mysql = require('mysql2/promise'),
  bcrypt = require('bcryptjs'), jwt = require('jsonwebtoken'), nodemailer = require('nodemailer'),
  crypto = require('node:crypto');
const SECRET = process.env.JWT_SECRET;
if (!SECRET) throw new Error('Define JWT_SECRET en .env');
const smtpSettings = ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM'];
const smtpConfigured = smtpSettings.every(key => process.env[key]);
const smtpPartiallyConfigured = smtpSettings.some(key => process.env[key]) && !smtpConfigured;
if (smtpPartiallyConfigured) throw new Error(`Configura todas las variables SMTP: ${smtpSettings.join(', ')}`);
if (process.env.NODE_ENV === 'production' && !smtpConfigured) {
  throw new Error('Configura SMTP_HOST, SMTP_USER, SMTP_PASS y SMTP_FROM para recuperación por correo');
}
const mailer = smtpConfigured
  ? nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: process.env.SMTP_SECURE === 'true',
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    })
  : null;
const app = express(); app.use(cors(), express.json());
const db = mysql.createPool({ host: process.env.DB_HOST || 'localhost', user: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || '', database: 'medireminder', dateStrings: true });

const wrap = fn => (req, res) => fn(req, res).catch(e => { console.error(e); res.status(500).json({ error: 'Error interno' }); });
const bad = (res, msg, c = 400) => res.status(c).json({ error: msg });
const auth = (req, res, next) => { try { const p = jwt.verify((req.headers.authorization || '').slice(7), SECRET);
  if (p.reset) throw 0; req.uid = p.uid; next(); } catch { bad(res, 'No autorizado', 401); } };
const pad = n => String(n).padStart(2, '0');
const fd = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const fdt = d => `${fd(d)} ${pad(d.getHours())}:${pad(d.getMinutes())}:00`;
const sign = (uid, extra = {}, exp = '7d') => jwt.sign({ uid, ...extra }, SECRET, { expiresIn: exp });
const emailOk = e => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e || '');
const escapeHtml = value => String(value).replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[char]);
const horasOk = h => Array.isArray(h) && h.length > 0 && h.every(x => /^([01]\d|2[0-3]):[0-5]\d$/.test(x));

// ---------- Autenticación (HU-01, HU-02, recuperación) ----------
app.post('/api/auth/register', wrap(async (req, res) => {
  const { nombre, correo, telefono, password } = req.body;
  if (!nombre || !emailOk(correo) || !password || password.length < 8) return bad(res, 'Datos inválidos (contraseña mínimo 8 caracteres)');
  const [ex] = await db.query('SELECT 1 FROM usuario WHERE correo=?', [correo]);
  if (ex.length) return bad(res, 'El correo ya existe', 409);
  const [r] = await db.query('INSERT INTO usuario(nombre,correo,telefono,contrasena_hash) VALUES(?,?,?,?)',
    [nombre, correo, telefono || null, await bcrypt.hash(password, 10)]);
  await db.query('INSERT INTO preferencia(id_usuario) VALUES(?)', [r.insertId]);
  res.status(201).json({ token: sign(r.insertId), usuario: { id: r.insertId, nombre, correo } });
}));
app.post('/api/auth/login', wrap(async (req, res) => {
  const [[u]] = await db.query('SELECT * FROM usuario WHERE correo=?', [req.body.correo]);
  if (!u || !(await bcrypt.compare(req.body.password || '', u.contrasena_hash))) return bad(res, 'Credenciales inválidas', 401);
  res.json({ token: sign(u.id_usuario), usuario: { id: u.id_usuario, nombre: u.nombre, correo: u.correo } });
}));
app.post('/api/auth/forgot', wrap(async (req, res) => {
  const correo = String(req.body.correo || '').trim().toLowerCase();
  if (!emailOk(correo)) return bad(res, 'Ingresa un correo válido');
  const [[u]] = await db.query('SELECT id_usuario,nombre FROM usuario WHERE correo=?', [correo]);
  if (!u) return res.json({ ok: true, developmentMode: !mailer });

  const code = String(crypto.randomInt(1000, 10000));
  const codeHash = await bcrypt.hash(code, 10);
  const expiresAt = fdt(new Date(Date.now() + 10 * 60000));
  await db.query('UPDATE codigo_recuperacion SET usado=1 WHERE id_usuario=? AND usado=0', [u.id_usuario]);
  const [record] = await db.query(
    'INSERT INTO codigo_recuperacion(id_usuario,codigo_hash,expira) VALUES(?,?,?)',
    [u.id_usuario, codeHash, expiresAt],
  );

  if (mailer) {
    try {
      await mailer.sendMail({
        from: process.env.SMTP_FROM,
        to: correo,
        subject: 'Código para recuperar tu cuenta de MediReminder',
        text: `Hola ${u.nombre},\n\nTu código de recuperación es: ${code}\n\nVence en 10 minutos. Si no solicitaste este código, puedes ignorar este mensaje.`,
        html: `<p>Hola ${escapeHtml(u.nombre)},</p><p>Tu código para recuperar MediReminder es:</p><p style="font-size:28px;font-weight:bold;letter-spacing:8px">${code}</p><p>Vence en 10 minutos. Si no solicitaste este código, puedes ignorar este mensaje.</p>`,
      });
    } catch (error) {
      await db.query('UPDATE codigo_recuperacion SET usado=1 WHERE id=?', [record.insertId]);
      console.error('No se pudo enviar el correo de recuperación:', error);
      return bad(res, 'No pudimos enviar el correo de recuperación. Inténtalo más tarde.', 503);
    }
  } else {
    console.log(`[DEV] Código de recuperación para ${correo}: ${code}`);
  }
  res.json({ ok: true, developmentMode: !mailer });
}));
app.post('/api/auth/verify', wrap(async (req, res) => {
  const correo = String(req.body.correo || '').trim().toLowerCase();
  const verified = await tx(async conn => {
    const [[u]] = await conn.query('SELECT id_usuario FROM usuario WHERE correo=?', [correo]);
    if (!u) return null;
    const [[c]] = await conn.query(
      'SELECT * FROM codigo_recuperacion WHERE id_usuario=? AND usado=0 AND intentos<5 AND expira>NOW() ORDER BY id DESC LIMIT 1 FOR UPDATE',
      [u.id_usuario],
    );
    if (!c) return null;
    const matches = await bcrypt.compare(String(req.body.codigo || ''), c.codigo_hash);
    if (!matches) {
      await conn.query(
        'UPDATE codigo_recuperacion SET usado=IF(intentos>=4,1,usado), intentos=intentos+1 WHERE id=?',
        [c.id],
      );
      return null;
    }
    await conn.query('UPDATE codigo_recuperacion SET usado=1 WHERE id=?', [c.id]);
    return { uid: u.id_usuario, recoveryId: c.id };
  });
  if (!verified) return bad(res, 'Código inválido o vencido');
  res.json({
    resetToken: sign(verified.uid, { reset: true, recoveryId: verified.recoveryId }, '10m'),
  });
}));
app.post('/api/auth/reset', wrap(async (req, res) => {
  let p; try { p = jwt.verify(req.body.resetToken, SECRET); if (!p.reset) throw 0; } catch { return bad(res, 'Sesión de recuperación inválida', 401); }
  if (!req.body.password || req.body.password.length < 8) return bad(res, 'Contraseña mínimo 8 caracteres');
  if (!p.recoveryId) return bad(res, 'Sesión de recuperación inválida', 401);
  const updated = await tx(async conn => {
    const [[recovery]] = await conn.query(
      'SELECT id FROM codigo_recuperacion WHERE id=? AND id_usuario=? AND usado=1 AND expira>NOW() FOR UPDATE',
      [p.recoveryId, p.uid],
    );
    if (!recovery) return false;
    await conn.query('UPDATE usuario SET contrasena_hash=? WHERE id_usuario=?',
      [await bcrypt.hash(req.body.password, 10), p.uid]);
    await conn.query('UPDATE codigo_recuperacion SET expira=NOW() WHERE id=?', [p.recoveryId]);
    return true;
  });
  if (!updated) return bad(res, 'El código de recuperación venció. Solicita uno nuevo.', 401);
  res.json({ ok: true });
}));
app.put('/api/profile', auth, wrap(async (req, res) => {
  const { nombre, telefono } = req.body;
  if (!nombre) return bad(res, 'El nombre es obligatorio');
  await db.query('UPDATE usuario SET nombre=?, telefono=? WHERE id_usuario=?', [nombre, telefono || null, req.uid]);
  res.json({ ok: true });
}));

// ---------- Generación de dosis programadas (HU-07) ----------
async function genDoses(conn, id, m) {
  const horas = m.horas.split(','), dias = m.dias_semana ? m.dias_semana.split(',').map(Number) : null;
  const now = new Date(), start = new Date(`${m.fecha_inicio}T00:00:00`);
  const end = new Date(Math.min(m.fecha_fin ? new Date(`${m.fecha_fin}T23:59:00`) : Infinity, now.getTime() + 30 * 864e5));
  const rows = [];
  if (m.intervalo_horas) {
    const [h, mi] = horas[0].split(':').map(Number);
    const t = new Date(start); t.setHours(h, mi);
    const intervalMs = m.intervalo_horas * 3600000;
    if (t < now) t.setTime(t.getTime() + Math.ceil((now - t) / intervalMs) * intervalMs);
    for (; t <= end; t.setTime(t.getTime() + intervalMs)) rows.push([id, fdt(t)]);
  } else for (const d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    if (dias && !dias.includes(d.getDay())) continue;
    for (const hh of horas) { const [h, mi] = hh.split(':').map(Number); const t = new Date(d); t.setHours(h, mi, 0);
      if (t >= now && t <= end) rows.push([id, fdt(t)]); }
  }
  const [existing] = await conn.query(`SELECT DATE_FORMAT(fecha_hora_programada,'%Y-%m-%d %H:%i:%s') scheduled
    FROM dosis WHERE id_medicamento=? AND estado='pendiente'
      AND fecha_hora_programada BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 30 DAY)`, [id]);
  const scheduled = new Set(existing.map(row => row.scheduled));
  const newRows = rows.filter(row => {
    if (scheduled.has(row[1])) return false;
    scheduled.add(row[1]);
    return true;
  });
  if (!newRows.length) return 0;
  await conn.query('INSERT INTO dosis(id_medicamento,fecha_hora_programada) VALUES ?', [newRows]);
  await conn.query(`INSERT INTO recordatorio(id_dosis,anticipacion)
    SELECT id_dosis,0 FROM dosis WHERE id_medicamento=? AND id_dosis NOT IN (SELECT id_dosis FROM recordatorio)`, [id]);
  return newRows.length;
}
function readMed(b) {
  if (!b.nombre || !b.dosis) return 'Nombre y dosis son obligatorios';
  if (!horasOk(b.horas)) return 'Horario inválido (use HH:MM)';
  if (b.cantidad != null && (!Number.isInteger(+b.cantidad) || +b.cantidad < 0)) return 'La cantidad no puede ser negativa';
  if (b.fecha_fin && b.fecha_inicio && b.fecha_fin < b.fecha_inicio) return 'La fecha fin es anterior al inicio';
  return null;
}
const medVals = b => [b.nombre, b.presentacion || null, b.dosis, b.via || 'oral', b.frecuencia || null, b.horas.join(','),
  b.intervalo_horas || null, b.dias_semana ? b.dias_semana.join(',') : null, b.fecha_inicio || fd(new Date()), b.fecha_fin || null];
const genArg = b => ({ ...b, horas: b.horas.join(','), dias_semana: b.dias_semana?.join(','), fecha_inicio: b.fecha_inicio || fd(new Date()) });
async function saveInv(conn, id, b) {
  if (b.cantidad == null) return;
  await conn.query(`INSERT INTO inventario(id_medicamento,cantidad_actual,unidad,minimo) VALUES(?,?,?,?)
    ON DUPLICATE KEY UPDATE cantidad_actual=VALUES(cantidad_actual),unidad=VALUES(unidad),minimo=VALUES(minimo)`,
    [id, +b.cantidad, b.unidad || 'tabletas', +b.minimo || 0]);
}
const tx = async fn => { const c = await db.getConnection(); try { await c.beginTransaction(); const r = await fn(c); await c.commit(); return r; }
  catch (e) { await c.rollback(); throw e; } finally { c.release(); } };

// ---------- Medicamentos (HU-03..06, HU-12, HU-14) ----------
app.get('/api/meds', auth, wrap(async (req, res) => {
  const { q, estado } = req.query; const p = [req.uid]; let w = '';
  if (q) { w += ' AND m.nombre LIKE ?'; p.push(`%${q}%`); }
  if (estado) { w += ' AND m.estado=?'; p.push(estado); }
  const [rows] = await db.query(`SELECT m.*, i.cantidad_actual, i.unidad, i.minimo,
    (SELECT MIN(fecha_hora_programada) FROM dosis d WHERE d.id_medicamento=m.id_medicamento AND d.estado='pendiente' AND d.fecha_hora_programada>=NOW()) proxima_dosis
    FROM medicamento m LEFT JOIN inventario i USING(id_medicamento) WHERE m.id_usuario=? ${w} ORDER BY m.nombre`, p);
  res.json(rows);
}));
app.post('/api/meds', auth, wrap(async (req, res) => {
  const err = readMed(req.body); if (err) return bad(res, err);
  const id = await tx(async c => {
    const [r] = await c.query(`INSERT INTO medicamento(nombre,presentacion,dosis,via,frecuencia,horas,intervalo_horas,dias_semana,fecha_inicio,fecha_fin,id_usuario)
      VALUES(?,?,?,?,?,?,?,?,?,?,?)`, [...medVals(req.body), req.uid]);
    await saveInv(c, r.insertId, req.body);
    await genDoses(c, r.insertId, genArg(req.body));
    return r.insertId;
  });
  res.status(201).json({ id });
}));
app.put('/api/meds/:id', auth, wrap(async (req, res) => {
  const err = readMed(req.body); if (err) return bad(res, err);
  const [[own]] = await db.query('SELECT 1 x FROM medicamento WHERE id_medicamento=? AND id_usuario=?', [req.params.id, req.uid]);
  if (!own) return bad(res, 'No encontrado', 404);
  await tx(async c => {
    await c.query(`UPDATE medicamento SET nombre=?,presentacion=?,dosis=?,via=?,frecuencia=?,horas=?,intervalo_horas=?,dias_semana=?,fecha_inicio=?,fecha_fin=? WHERE id_medicamento=?`,
      [...medVals(req.body), req.params.id]);
    await saveInv(c, req.params.id, req.body);
    // el historial se conserva: solo se regeneran las dosis pendientes futuras
    await c.query("DELETE FROM dosis WHERE id_medicamento=? AND estado='pendiente' AND fecha_hora_programada>=NOW()", [req.params.id]);
    await genDoses(c, req.params.id, genArg(req.body));
  });
  res.json({ ok: true });
}));
app.delete('/api/meds/:id', auth, wrap(async (req, res) => {
  const [r] = await db.query("UPDATE medicamento SET estado='finalizado' WHERE id_medicamento=? AND id_usuario=?", [req.params.id, req.uid]);
  if (!r.affectedRows) return bad(res, 'No encontrado', 404);
  await db.query("DELETE FROM dosis WHERE id_medicamento=? AND estado='pendiente' AND fecha_hora_programada>=NOW()", [req.params.id]);
  res.json({ ok: true });
}));

// ---------- Dosis, toma e historial (HU-09, HU-10) ----------
app.get('/api/doses', auth, wrap(async (req, res) => {
  const day = req.query.date || fd(new Date());
  const [rows] = await db.query(`SELECT d.id_dosis,d.fecha_hora_programada,d.estado,m.nombre,m.dosis FROM dosis d JOIN medicamento m USING(id_medicamento)
    WHERE m.id_usuario=? AND DATE(d.fecha_hora_programada)=? ORDER BY d.fecha_hora_programada`, [req.uid, day]);
  res.json(rows);
}));
app.get('/api/doses/upcoming', auth, wrap(async (req, res) => {
  const requestedDays = Number.parseInt(req.query.days, 10);
  const days = Number.isInteger(requestedDays) ? Math.min(Math.max(requestedDays, 1), 30) : 30;
  await tx(async conn => {
    const [meds] = await conn.query(`SELECT id_medicamento,horas,intervalo_horas,dias_semana,fecha_inicio,fecha_fin
      FROM medicamento WHERE id_usuario=? AND estado='activo'`, [req.uid]);
    for (const med of meds) await genDoses(conn, med.id_medicamento, med);
  });
  const [rows] = await db.query(`SELECT d.id_dosis,d.fecha_hora_programada,d.estado,m.nombre,m.dosis FROM dosis d
    JOIN medicamento m USING(id_medicamento)
    WHERE m.id_usuario=? AND d.estado='pendiente'
      AND d.fecha_hora_programada BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL ? DAY)
    ORDER BY d.fecha_hora_programada LIMIT 450`, [req.uid, days]);
  res.json(rows);
}));
app.post('/api/doses/:id/status', auth, wrap(async (req, res) => {
  const { estado, observacion } = req.body;
  if (!['tomada', 'omitida', 'pospuesta'].includes(estado)) return bad(res, 'Estado inválido');
  const [[d]] = await db.query(`SELECT d.*,m.id_usuario FROM dosis d JOIN medicamento m USING(id_medicamento) WHERE d.id_dosis=?`, [req.params.id]);
  if (!d || d.id_usuario !== req.uid) return bad(res, 'Dosis no encontrada', 404);
  if (!['pendiente', 'pospuesta'].includes(d.estado)) return bad(res, 'La dosis ya fue registrada', 409);
  await tx(async c => {
    if (estado === 'pospuesta') await c.query("UPDATE dosis SET estado='pendiente', fecha_hora_programada=DATE_ADD(fecha_hora_programada, INTERVAL 10 MINUTE) WHERE id_dosis=?", [d.id_dosis]);
    else await c.query('UPDATE dosis SET estado=? WHERE id_dosis=?', [estado, d.id_dosis]);
    await c.query('INSERT INTO historial(id_dosis,fecha_hora_real,resultado,observacion) VALUES(?,NOW(),?,?)', [d.id_dosis, estado, observacion || null]);
    if (estado === 'tomada') await c.query('UPDATE inventario SET cantidad_actual=GREATEST(cantidad_actual-1,0) WHERE id_medicamento=?', [d.id_medicamento]);
  });
  res.json({ ok: true });
}));
app.get('/api/history', auth, wrap(async (req, res) => {
  const { medId, from, to } = req.query; const p = [req.uid]; let w = '';
  if (medId) { w += ' AND m.id_medicamento=?'; p.push(medId); }
  if (from) { w += ' AND h.fecha_hora_real>=?'; p.push(from); }
  if (to) { w += ' AND h.fecha_hora_real<=?'; p.push(`${to} 23:59:59`); }
  const [rows] = await db.query(`SELECT h.id_historial,h.fecha_hora_real,h.resultado,h.observacion,m.nombre,m.dosis FROM historial h
    JOIN dosis d USING(id_dosis) JOIN medicamento m USING(id_medicamento) WHERE m.id_usuario=? ${w} ORDER BY h.fecha_hora_real DESC LIMIT 200`, p);
  res.json(rows);
}));

// ---------- Estadísticas (HU-11) ----------
async function stats(uid, range) {
  const days = { week: 7, month: 30, year: 365 }[range] || 7;
  const from = fdt(new Date(Date.now() - days * 864e5)), p = [uid, from];
  const base = `FROM dosis d JOIN medicamento m USING(id_medicamento) WHERE m.id_usuario=? AND d.fecha_hora_programada BETWEEN ? AND NOW()`;
  const [porDia] = await db.query(`SELECT DATE(d.fecha_hora_programada) dia, SUM(d.estado='tomada') tomadas, COUNT(*) total ${base} GROUP BY dia ORDER BY dia`, p);
  const [porMed] = await db.query(`SELECT m.nombre, SUM(d.estado='tomada') tomadas, COUNT(*) total ${base} GROUP BY m.id_medicamento,m.nombre`, p);
  const n = r => ({ ...r, tomadas: Number(r.tomadas), total: Number(r.total) });
  const T = porDia.reduce((a, r) => a + Number(r.total), 0), K = porDia.reduce((a, r) => a + Number(r.tomadas), 0);
  return { porcentaje: T ? Math.round(K * 100 / T) : null, porDia: porDia.map(n), porMed: porMed.map(n) };
}
app.get('/api/stats', auth, wrap(async (req, res) => res.json(await stats(req.uid, req.query.range))));

// ---------- Notificaciones in-app (HU-08, HU-13) ----------
app.get('/api/notifications', auth, wrap(async (req, res) => {
  const out = [];
  const [om] = await db.query(`SELECT m.nombre FROM dosis d JOIN medicamento m USING(id_medicamento) WHERE m.id_usuario=? AND d.estado='omitida' AND d.fecha_hora_programada>=DATE_SUB(NOW(),INTERVAL 1 DAY)`, [req.uid]);
  om.forEach(r => out.push({ tipo: 'omitida', texto: `Dosis de ${r.nombre} omitida` }));
  const [pr] = await db.query(`SELECT m.nombre,d.fecha_hora_programada f FROM dosis d JOIN medicamento m USING(id_medicamento) WHERE m.id_usuario=? AND d.estado='pendiente' AND d.fecha_hora_programada BETWEEN NOW() AND DATE_ADD(NOW(),INTERVAL 2 HOUR)`, [req.uid]);
  pr.forEach(r => out.push({ tipo: 'toma', texto: `Toma de ${r.nombre} a las ${r.f.slice(11, 16)}` }));
  const [lo] = await db.query(`SELECT m.nombre,i.cantidad_actual c FROM inventario i JOIN medicamento m USING(id_medicamento) WHERE m.id_usuario=? AND i.minimo>0 AND i.cantidad_actual<=i.minimo`, [req.uid]);
  lo.forEach(r => out.push({ tipo: 'inventario', texto: `Quedan ${r.c} dosis de ${r.nombre}` }));
  res.json(out);
}));

// ---------- Asistente (RG-15): reglas de seguridad + contexto del usuario ----------
const CLINICA = /(diagn|receta|recet|cambiar.*dosis|subir.*dosis|bajar.*dosis|duplicar|dejar de tomar|suspender|interacci|puedo tomar|s[ií]ntoma|me duele|efecto secundario|sobredosis)/i;
app.post('/api/assistant', auth, wrap(async (req, res) => {
  const msg = String(req.body.mensaje || '').trim().slice(0, 500);
  if (!msg) return bad(res, 'Escribe una consulta');
  let r;
  if (CLINICA.test(msg)) r = 'No puedo diagnosticar ni recomendar cambios de dosis o tratamientos. Consulta a tu médico o farmacéutico. Puedo ayudarte con tus horarios y el uso de la app.';
  else if (/hoy|pr[oó]xim|tomar/i.test(msg)) {
    const [rows] = await db.query(`SELECT d.fecha_hora_programada f,d.estado,m.nombre,m.dosis FROM dosis d JOIN medicamento m USING(id_medicamento)
      WHERE m.id_usuario=? AND DATE(d.fecha_hora_programada)=CURDATE() ORDER BY d.fecha_hora_programada`, [req.uid]);
    r = rows.length ? 'Tus dosis de hoy:\n' + rows.map(x => `• ${x.f.slice(11, 16)} ${x.nombre} ${x.dosis} (${x.estado})`).join('\n') : 'No hay próximas dosis registradas para hoy.';
  } else if (/cumpl|adherencia|porcentaje/i.test(msg)) {
    const s = await stats(req.uid, 'week');
    r = s.porcentaje == null ? 'Aún no hay información suficiente para calcular tu cumplimiento.' : `En los últimos 7 días tomaste el ${s.porcentaje}% de tus dosis programadas. Es solo un dato de seguimiento, no una valoración médica.`;
  } else r = 'Puedo ayudarte con: tus dosis de hoy, tu resumen de cumplimiento y cómo usar la app (registrar medicamentos, configurar horarios, ver historial). ¿Qué necesitas?';
  let [[cv]] = await db.query("SELECT id_conversacion FROM conversacion_ia WHERE id_usuario=? AND estado='activa' ORDER BY id_conversacion DESC LIMIT 1", [req.uid]);
  if (!cv) { const [i] = await db.query('INSERT INTO conversacion_ia(id_usuario) VALUES(?)', [req.uid]); cv = { id_conversacion: i.insertId }; }
  await db.query('INSERT INTO interaccion_ia(id_conversacion,consulta,respuesta) VALUES(?,?,?)', [cv.id_conversacion, msg, r]);
  res.json({ respuesta: r }); // TODO: sustituir las reglas por un LLM con este mismo contexto y filtro CLINICA
}));

async function ensureRecoveryAttemptsColumn() {
  const [[column]] = await db.query(
    `SELECT COUNT(*) AS found FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='codigo_recuperacion' AND COLUMN_NAME='intentos'`,
  );
  if (!Number(column.found)) {
    await db.query(
      'ALTER TABLE codigo_recuperacion ADD COLUMN intentos TINYINT UNSIGNED NOT NULL DEFAULT 0',
    );
  }
}

ensureRecoveryAttemptsColumn()
  .then(() => app.listen(process.env.PORT || 3000, () => console.log('MediReminder API lista')))
  .catch(error => {
    console.error('No se pudo preparar la base para la recuperación de cuenta:', error);
    process.exitCode = 1;
  });
