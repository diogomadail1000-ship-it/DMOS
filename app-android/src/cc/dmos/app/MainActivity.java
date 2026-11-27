package cc.dmos.app;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Bundle;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * DMOS para Android. A interface é uma página local (assets/www) numa WebView; esta classe dá-lhe
 * três coisas que uma página não tem: pedidos à rede sem as restrições do navegador (para ler as
 * fontes de notícias diretamente, como o DMOS Hub), abrir ligações no navegador e partilhar texto.
 *
 * A WebView só mostra a página local. Nenhuma página da internet é carregada dentro da aplicação,
 * por isso a ponte «DmosNative» nunca fica ao alcance de conteúdo remoto.
 */
public class MainActivity extends Activity {
    private static final String HOME = "file:///android_asset/www/index.html";
    private static final int MAX_BYTES = 3 * 1024 * 1024;
    private static final int MAX_REDIRECTS = 5;
    private static final int DEADLINE_SECONDS = 25;
    private static final Pattern SAFE_ID = Pattern.compile("[A-Za-z0-9_-]{1,40}");
    private static final Pattern XML_ENCODING = Pattern.compile("<\\?xml[^>]*encoding=[\"']([A-Za-z0-9._-]+)[\"']");

    private WebView web;
    private final Set<String> hosts = java.util.Collections.synchronizedSet(new HashSet<String>());
    private final ExecutorService pool = Executors.newFixedThreadPool(4);
    // Respostas prontas, à espera de serem recolhidas pela página com take().
    private final ConcurrentHashMap<String, String> prontas = new ConcurrentHashMap<>();
    // Corta os pedidos que se arrastam, para um servidor lento não prender a rede da aplicação.
    private final ScheduledExecutorService watchdog = Executors.newSingleThreadScheduledExecutor();

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        loadAllowedHosts();

        web = new WebView(this);
        web.setBackgroundColor(getColor(R.color.dmos_bg));
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setTextZoom(textZoom(getResources().getConfiguration()));
        web.setOverScrollMode(WebView.OVER_SCROLL_NEVER);
        web.addJavascriptInterface(new Bridge(), "DmosNative");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                String url = request.getUrl().toString();
                if (url.startsWith("file:///android_asset/www/")) return false;
                openExternal(url);
                return true;
            }
        });
        setContentView(web);
        if (state == null || web.restoreState(state) == null) web.loadUrl(HOME);
    }

    /** O tamanho de letra da página segue o que o utilizador escolheu no telemóvel. */
    private static int textZoom(Configuration config) {
        return Math.max(85, Math.min(200, Math.round(100 * config.fontScale)));
    }

    @Override
    public void onConfigurationChanged(Configuration config) {
        super.onConfigurationChanged(config);
        if (web != null) web.getSettings().setTextZoom(textZoom(config));
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    @Override
    public void onBackPressed() {
        // As páginas da aplicação são âncoras (#noticias…), por isso «voltar» anda entre elas.
        if (web.canGoBack()) web.goBack(); else super.onBackPressed();
    }

    @Override
    protected void onDestroy() {
        pool.shutdownNow();
        watchdog.shutdownNow();
        web.removeJavascriptInterface("DmosNative");
        web.destroy();
        super.onDestroy();
    }

    /** Só se contactam o site do DMOS, o repositório e as fontes de notícias de sources.json. */
    private void loadAllowedHosts() {
        hosts.add("dmos.cc");
        hosts.add("raw.githubusercontent.com");
        try (InputStream in = getAssets().open("www/data/sources.json")) {
            JSONArray list = new JSONArray(new String(readAll(in, MAX_BYTES), StandardCharsets.UTF_8));
            for (int i = 0; i < list.length(); i++) {
                String host = new URL(list.getJSONObject(i).getString("url")).getHost();
                if (host != null) hosts.add(host.toLowerCase(Locale.ROOT));
            }
        } catch (Exception ignored) {
            // Sem a lista, as notícias ficam indisponíveis; o resto da aplicação funciona.
        }
        // Os anfitriões das fontes que o utilizador acrescentou.
        hosts.addAll(prefs().getStringSet("fontes", new HashSet<String>()));
    }

    private SharedPreferences prefs() {
        return getSharedPreferences("dmos", MODE_PRIVATE);
    }

    private void openExternal(String url) {
        if (url == null || !(url.startsWith("https://") || url.startsWith("http://"))) return;
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (ActivityNotFoundException ignored) {
            // Sem navegador instalado não há nada a fazer.
        }
    }

    /** Recusa nomes locais e endereços privados, para a aplicação nunca ser usada para sondar a rede de casa. */
    private static boolean isPublicHost(String host) {
        if (host == null || host.isEmpty() || !host.contains(".") || host.endsWith(".local") || host.endsWith(".internal")) return false;
        try {
            for (InetAddress a : InetAddress.getAllByName(host)) {
                if (a.isAnyLocalAddress() || a.isLoopbackAddress() || a.isLinkLocalAddress() || a.isSiteLocalAddress() || a.isMulticastAddress()) return false;
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static byte[] readAll(InputStream in, int max) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[16384];
        int n;
        while ((n = in.read(buf)) > 0) {
            if (out.size() + n > max) throw new IllegalStateException("resposta demasiado grande");
            out.write(buf, 0, n);
        }
        return out.toByteArray();
    }

    /** O conjunto de caracteres do cabeçalho HTTP, ou da declaração XML, ou UTF-8. */
    private static Charset charsetOf(String contentType, byte[] data) {
        String name = null;
        if (contentType != null) {
            Matcher m = Pattern.compile("charset=\"?([A-Za-z0-9._-]+)", Pattern.CASE_INSENSITIVE).matcher(contentType);
            if (m.find()) name = m.group(1);
        }
        if (name == null) {
            String head = new String(data, 0, Math.min(data.length, 200), StandardCharsets.ISO_8859_1);
            Matcher m = XML_ENCODING.matcher(head);
            if (m.find()) name = m.group(1);
        }
        try {
            return name == null ? StandardCharsets.UTF_8 : Charset.forName(name);
        } catch (Exception e) {
            return StandardCharsets.UTF_8;
        }
    }

    private final class Bridge {
        /**
         * Pede um endereço HTTPS de um dos anfitriões permitidos. Quando termina, avisa a página com
         * window.__dmosReady(id), e a página recolhe a resposta com take(id). Estado 0 significa falha
         * de rede ou pedido recusado.
         */
        @JavascriptInterface
        public void fetch(final String id, final String address) {
            if (id == null || !SAFE_ID.matcher(id).matches()) return;
            pool.execute(new Runnable() {
                @Override
                public void run() {
                    int status = 0;
                    String body = "";
                    final HttpURLConnection[] atual = new HttpURLConnection[1];
                    // Prazo para o pedido inteiro, redirecionamentos incluídos.
                    ScheduledFuture<?> prazo = watchdog.schedule(new Runnable() {
                        @Override
                        public void run() {
                            HttpURLConnection c = atual[0];
                            if (c != null) c.disconnect();
                        }
                    }, DEADLINE_SECONDS, TimeUnit.SECONDS);
                    try {
                        URL url = new URL(address);
                        String primeiro = url.getHost() == null ? "" : url.getHost().toLowerCase(Locale.ROOT);
                        if (!hosts.contains(primeiro)) throw new SecurityException(primeiro);
                        for (int salto = 0; ; salto++) {
                            // Cada passo tem de ser HTTPS e para um endereço público.
                            if (!"https".equals(url.getProtocol()) || url.getUserInfo() != null || !isPublicHost(url.getHost())) throw new SecurityException(url.getHost());
                            HttpURLConnection c = (HttpURLConnection) url.openConnection();
                            atual[0] = c;
                            if (prazo.isDone()) throw new IllegalStateException("prazo");
                            c.setConnectTimeout(10000);
                            c.setReadTimeout(15000);
                            c.setInstanceFollowRedirects(false);
                            c.setRequestProperty("User-Agent", "DMOS-Android/" + BuildInfo.VERSION + " (+https://dmos.cc)");
                            c.setRequestProperty("Accept", "application/rss+xml, application/atom+xml, application/xml, text/xml, application/json, text/plain, */*");
                            status = c.getResponseCode();
                            String para = c.getHeaderField("Location");
                            if (status >= 300 && status < 400 && para != null) {
                                if (salto >= MAX_REDIRECTS) throw new IllegalStateException("demasiados redirecionamentos");
                                url = new URL(url, para);
                                c.disconnect();
                                continue;
                            }
                            InputStream in = status < 400 ? c.getInputStream() : c.getErrorStream();
                            if (in != null) {
                                byte[] data = readAll(in, MAX_BYTES);
                                String text = new String(data, charsetOf(c.getContentType(), data));
                                body = Base64.encodeToString(text.getBytes(StandardCharsets.UTF_8), Base64.NO_WRAP);
                            }
                            break;
                        }
                    } catch (Exception e) {
                        status = 0;
                        body = "";
                    } finally {
                        prazo.cancel(false);
                        if (atual[0] != null) atual[0].disconnect();
                    }
                    // A resposta fica guardada e a página é avisada. A página também pergunta por ela
                    // de tempos a tempos, por isso o aviso pode falhar sem se perder nada.
                    prontas.put(id, status + "," + body);
                    final String js = "window.__dmosReady&&window.__dmosReady(" + JSONObject.quote(id) + ")";
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            if (!isDestroyed()) web.evaluateJavascript(js, null);
                        }
                    });
                }
            });
        }

        /** Entrega à página a resposta de um pedido, como «estado,textoEmBase64», ou vazio se ainda não chegou. */
        @JavascriptInterface
        public String take(String id) {
            if (id == null) return "";
            String r = prontas.remove(id);
            return r == null ? "" : r;
        }

        /** Abre uma ligação http(s) no navegador do telemóvel. */
        @JavascriptInterface
        public void open(final String url) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    openExternal(url);
                }
            });
        }

        /** Abre o menu «Partilhar» do Android com um texto, por exemplo a ligação de descarga. */
        @JavascriptInterface
        public void share(final String text) {
            if (text == null || text.length() > 2000) return;
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    Intent send = new Intent(Intent.ACTION_SEND);
                    send.setType("text/plain");
                    send.putExtra(Intent.EXTRA_TEXT, text);
                    startActivity(Intent.createChooser(send, getString(R.string.share_title)));
                }
            });
        }

        @JavascriptInterface
        public String version() {
            return BuildInfo.VERSION;
        }

        /**
         * Autoriza o anfitrião de uma fonte acrescentada pelo utilizador. Só aceita
         * endereços HTTPS com um nome de anfitrião público; devolve false se recusar.
         */
        @JavascriptInterface
        public boolean allowSource(String address) {
            if (address == null || address.length() > 500) return false;
            try {
                URL url = new URL(address);
                String host = url.getHost() == null ? "" : url.getHost().toLowerCase(Locale.ROOT);
                if (!"https".equals(url.getProtocol()) || url.getUserInfo() != null) return false;
                if (!host.matches("[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+") || host.matches("[0-9.]+")) return false;
                if (hosts.add(host)) {
                    Set<String> saved = new HashSet<String>(prefs().getStringSet("fontes", new HashSet<String>()));
                    saved.add(host);
                    prefs().edit().putStringSet("fontes", saved).apply();
                }
                return true;
            } catch (Exception e) {
                return false;
            }
        }
    }
}
