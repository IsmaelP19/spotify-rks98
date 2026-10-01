// Pega esto en la consola de la página del RK Web Driver ANTES de elegir el teclado.
// Envuelve sendFeatureReport y receiveFeatureReport, guarda los bytes y llama al original.
// No envía ningún report por sí solo. No escucha pulsaciones.
// Después de la prueba: copy(JSON.stringify(window.__rkHidLog, null, 2))
(() => {
  if (window.__rkHidObserveInstalled) return;
  const send = HIDDevice.prototype.sendFeatureReport;
  const receive = HIDDevice.prototype.receiveFeatureReport;
  const log = [];
  const hex = (data) => {
    const bytes = new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
    return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
  };
  HIDDevice.prototype.sendFeatureReport = function (reportId, data) {
    log.push({ t: new Date().toISOString(), op: "sendFeatureReport", reportId, byteLength: data.byteLength, hex: hex(data) });
    return send.call(this, reportId, data);
  };
  HIDDevice.prototype.receiveFeatureReport = function (reportId) {
    const pending = receive.call(this, reportId);
    return Promise.resolve(pending).then((data) => {
      log.push({ t: new Date().toISOString(), op: "receiveFeatureReport", reportId, byteLength: data.byteLength, hex: hex(data) });
      return data;
    });
  };
  window.__rkHidLog = log;
  window.__rkHidObserveInstalled = true;
  console.log("Observador HID instalado. Aún no se ha enviado nada.");
})();
