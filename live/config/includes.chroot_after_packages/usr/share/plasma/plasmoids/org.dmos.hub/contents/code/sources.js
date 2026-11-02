// News sources offered by DMOS. Shared by the desktop hub and the welcome app.
// Only the sources the user turns on are ever contacted.
.pragma library

var list = [
    { id: "publico", name: "Público", kind: "Atualidade · PT", url: "https://feeds.feedburner.com/PublicoRSS" },
    { id: "observador", name: "Observador", kind: "Atualidade · PT", url: "https://observador.pt/feed/" },
    { id: "rtp", name: "RTP Notícias", kind: "Atualidade · PT", url: "https://www.rtp.pt/noticias/rss" },
    { id: "eco", name: "ECO", kind: "Economia · PT", url: "https://eco.sapo.pt/feed/" },
    { id: "sapotek", name: "SAPO Tek", kind: "Tecnologia · PT", url: "https://tek.sapo.pt/feed/" },
    { id: "pplware", name: "Pplware", kind: "Tecnologia · PT", url: "https://pplware.sapo.pt/feed/" },
    { id: "bbc", name: "BBC News", kind: "Atualidade · EN", url: "https://feeds.bbci.co.uk/news/rss.xml" },
    { id: "verge", name: "The Verge", kind: "Tecnologia · EN", url: "https://www.theverge.com/rss/index.xml" },
    { id: "ars", name: "Ars Technica", kind: "Ciência e tecnologia · EN", url: "https://feeds.arstechnica.com/arstechnica/index" },
    { id: "hn", name: "Hacker News", kind: "Tecnologia · EN", url: "https://hnrss.org/frontpage" }
];

function byId(id) {
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id) return list[i];
    }
    return null;
}

// Plain-text value of an XML fragment: CDATA unwrapped, tags dropped, entities decoded.
function clean(text) {
    if (!text) return "";
    text = text.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").replace(/<[^>]+>/g, "");
    text = text.replace(/&#(\d+);/g, function (m, n) { return String.fromCharCode(parseInt(n, 10)); })
               .replace(/&#x([0-9a-f]+);/gi, function (m, n) { return String.fromCharCode(parseInt(n, 16)); })
               .replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&lt;/g, "<")
               .replace(/&gt;/g, ">").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
    return text.replace(/\s+/g, " ").trim();
}

function tag(block, name) {
    var m = block.match(new RegExp("<" + name + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + name + ">", "i"));
    return m ? m[1] : "";
}

// Items of an RSS 2.0 or Atom document, newest first as the feed gives them.
function parse(xml, source) {
    var items = [];
    var blocks = xml.match(/<item[\s>][\s\S]*?<\/item>/gi) || xml.match(/<entry[\s>][\s\S]*?<\/entry>/gi) || [];
    for (var i = 0; i < blocks.length && i < 15; i++) {
        var b = blocks[i];
        var link = clean(tag(b, "link"));
        if (!link) {
            var href = b.match(/<link[^>]*href="([^"]+)"/i);
            link = href ? href[1].replace(/&amp;/g, "&") : "";
        }
        var when = Date.parse(clean(tag(b, "pubDate") || tag(b, "updated") || tag(b, "published") || tag(b, "dc:date")));
        var title = clean(tag(b, "title"));
        if (title && link) {
            items.push({ title: title, link: link, time: isNaN(when) ? 0 : when, source: source.name });
        }
    }
    return items;
}
