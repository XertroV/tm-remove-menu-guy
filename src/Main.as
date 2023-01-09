void Main() {
    await({
        startnew(GetStatusFromOpenplanet),
        startnew(WaitForMenu)
    });
    yield();
    if (g_isEnabled)
        PatchMenuCode();
}

// this will be set to true in GetStatusFromOpenplanet
bool g_isEnabled = false;

void GetStatusFromOpenplanet() {
    auto req = Net::HttpGet("https://openplanet.dev/plugin/remove-menu-guy/config/status");
    while (!req.Finished()) yield();
    if (req.ResponseCode() != 200) {
        warn('getting plugin enabled status: code: ' + req.ResponseCode() + '; error: ' + req.Error() + '; body: ' + req.String());
        RetryGetStatus(1000);
    }
    try {
        auto j = Json::Parse(req.String());
        g_isEnabled = bool(j['enabled']);
        trace('set enabled to: ' + tostring(g_isEnabled));
    } catch {
        warn("exception: " + getExceptionInfo());
        RetryGetStatus(1000);
    }
}

uint retries = 0;

void RetryGetStatus(uint delay) {
    trace('retying GetStatusFromOpenplanet in ' + delay + ' ms');
    sleep(delay);
    retries++;
    if (retries > 5) {
        warn('not retying anymore, too many failures.');
        return;
    }
    trace('retrying...');
    GetStatusFromOpenplanet();
}

void WaitForMenu() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    while (app.MenuManager is null) yield();
    while (app.MenuManager.MenuCustom_CurrentManiaApp is null) yield();
    // the bg page is index 12 ish
    while (app.MenuManager.MenuCustom_CurrentManiaApp.UILayers.Length < 15) yield();
}

void PatchMenuCode() {
    auto mm = cast<CTrackMania>(GetApp()).MenuManager;
    auto maniaApp = mm.MenuCustom_CurrentManiaApp;
    for (uint i = 0; i < maniaApp.UILayers.Length; i++) {
        auto layer = maniaApp.UILayers[i];
        if (!layer.ManialinkPageUtf8.SubStr(0, 200).Contains('<manialink name="Overlay_MenuBackground" version="3">'))
            continue;
        string newML = layer.ManialinkPageUtf8
            .Replace("HomeBackground.CameraScene.SceneId = MenuSceneMgr", "// HomeBackground.CameraScene.SceneId = MenuSceneMgr");
        layer.ManialinkPage = newML;
        break;
    }
}
