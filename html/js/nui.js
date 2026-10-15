// Local fallback so this file also works when opened directly in a browser for design/preview work.
window.GetParentResourceName = window.GetParentResourceName || function () {
    return 'aj-vehiclemenu';
};

function postNui(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).then((resp) => resp.json().catch(() => ({}))).catch(() => ({}));
}
