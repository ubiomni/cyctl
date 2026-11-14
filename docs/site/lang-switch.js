// Language switcher for mdBook bilingual site
(function() {
    var path = window.location.pathname;
    var isZh = path.indexOf('/zh/') !== -1;
    var switchPath = isZh
        ? path.replace('/zh/', '/en/')
        : path.replace('/en/', '/zh/');

    var div = document.createElement('div');
    div.className = 'language-switch';
    div.innerHTML =
        '<a href="' + (isZh ? switchPath : '#') + '"' + (!isZh ? ' class="active"' : '') + '>EN</a>' +
        '<a href="' + (!isZh ? switchPath : '#') + '"' + (isZh ? ' class="active"' : '') + '>中文</a>';

    var menuBar = document.querySelector('.right-buttons');
    if (menuBar) {
        menuBar.prepend(div);
    } else {
        document.body.prepend(div);
    }
})();
