-- MediReminder: modelo relacional (sec. 4.4) + entidades del asistente IA (sec. 5.1)
CREATE DATABASE IF NOT EXISTS medireminder CHARACTER SET utf8mb4;
USE medireminder;
CREATE TABLE usuario(
  id_usuario INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(100) NOT NULL,
  correo VARCHAR(100) NOT NULL UNIQUE, telefono VARCHAR(20),
  contrasena_hash VARCHAR(255) NOT NULL, creado DATETIME DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE medicamento(
  id_medicamento INT AUTO_INCREMENT PRIMARY KEY, id_usuario INT NOT NULL,
  nombre VARCHAR(100) NOT NULL, presentacion VARCHAR(50), dosis VARCHAR(50) NOT NULL,
  via VARCHAR(30) DEFAULT 'oral', frecuencia VARCHAR(50),
  horas VARCHAR(100) NOT NULL,
  intervalo_horas INT NULL,
  dias_semana VARCHAR(20) NULL,
  fecha_inicio DATE NOT NULL, fecha_fin DATE NULL,
  estado ENUM('activo','pausado','finalizado') DEFAULT 'activo',
  FOREIGN KEY(id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  INDEX(id_usuario,estado));
CREATE TABLE dosis(
  id_dosis INT AUTO_INCREMENT PRIMARY KEY, id_medicamento INT NOT NULL,
  fecha_hora_programada DATETIME NOT NULL,
  estado ENUM('pendiente','tomada','omitida','pospuesta') DEFAULT 'pendiente',
  FOREIGN KEY(id_medicamento) REFERENCES medicamento(id_medicamento) ON DELETE CASCADE,
  INDEX(id_medicamento,fecha_hora_programada));
CREATE TABLE historial(
  id_historial INT AUTO_INCREMENT PRIMARY KEY, id_dosis INT NOT NULL,
  fecha_hora_real DATETIME NOT NULL, resultado ENUM('tomada','omitida','pospuesta') NOT NULL,
  observacion TEXT, FOREIGN KEY(id_dosis) REFERENCES dosis(id_dosis) ON DELETE CASCADE);
CREATE TABLE recordatorio(
  id_recordatorio INT AUTO_INCREMENT PRIMARY KEY, id_dosis INT NOT NULL,
  anticipacion INT DEFAULT 0, enviado BOOLEAN DEFAULT FALSE,
  estado ENUM('activo','cancelado') DEFAULT 'activo',
  FOREIGN KEY(id_dosis) REFERENCES dosis(id_dosis) ON DELETE CASCADE);
CREATE TABLE inventario(
  id_inventario INT AUTO_INCREMENT PRIMARY KEY, id_medicamento INT NOT NULL UNIQUE,
  cantidad_actual INT NOT NULL CHECK (cantidad_actual>=0), unidad VARCHAR(20) DEFAULT 'tabletas',
  minimo INT DEFAULT 0, FOREIGN KEY(id_medicamento) REFERENCES medicamento(id_medicamento) ON DELETE CASCADE);
CREATE TABLE preferencia(
  id_preferencia INT AUTO_INCREMENT PRIMARY KEY, id_usuario INT NOT NULL UNIQUE,
  notificaciones_activas BOOLEAN DEFAULT TRUE, anticipacion_default INT DEFAULT 0,
  FOREIGN KEY(id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE);
CREATE TABLE codigo_recuperacion(
  id INT AUTO_INCREMENT PRIMARY KEY, id_usuario INT NOT NULL, codigo_hash VARCHAR(100) NOT NULL,
  expira DATETIME NOT NULL, usado BOOLEAN DEFAULT FALSE, intentos TINYINT UNSIGNED NOT NULL DEFAULT 0,
  FOREIGN KEY(id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE);
CREATE TABLE conversacion_ia(
  id_conversacion INT AUTO_INCREMENT PRIMARY KEY, id_usuario INT NOT NULL,
  fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP, estado ENUM('activa','cerrada') DEFAULT 'activa',
  FOREIGN KEY(id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE);
CREATE TABLE interaccion_ia(
  id_interaccion INT AUTO_INCREMENT PRIMARY KEY, id_conversacion INT NOT NULL,
  fecha_hora DATETIME DEFAULT CURRENT_TIMESTAMP, consulta TEXT NOT NULL, respuesta TEXT NOT NULL,
  FOREIGN KEY(id_conversacion) REFERENCES conversacion_ia(id_conversacion) ON DELETE CASCADE);
