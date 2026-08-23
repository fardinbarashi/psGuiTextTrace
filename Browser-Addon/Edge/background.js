// Open TextTrace in its own tab when the toolbar icon is clicked.
// A full page (rather than a cramped popup) is needed for the folder
// picker and the results table.
chrome.action.onClicked.addListener(async () => {
  const url = chrome.runtime.getURL("app.html");

  // Reuse an already-open TextTrace tab if one exists.
  const existing = await chrome.tabs.query({ url });
  if (existing.length > 0) {
    await chrome.tabs.update(existing[0].id, { active: true });
    await chrome.windows.update(existing[0].windowId, { focused: true });
  } else {
    await chrome.tabs.create({ url });
  }
});
