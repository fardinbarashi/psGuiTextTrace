// Firefox exponerar `browser`; fall tillbaka på `chrome`.
const api = typeof browser !== "undefined" ? browser : chrome;

// Popup finns inte -> onClicked triggas. Öppna sökaren i en egen flik,
// eftersom filläsning av stora mappar tar tid och en popup stängs vid fokusbyte.
api.action.onClicked.addListener(() => {
  api.tabs.create({ url: api.runtime.getURL("index.html") });
});
