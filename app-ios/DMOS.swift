// DMOS para iPhone e iPad. Uma janela com uma WKWebView que mostra a página local «www» (a mesma
// interface da aplicação para Android, em app-android/www). Este código dá à página o que um
// navegador não dá: ler as fontes de notícias sem as restrições de origem, abrir ligações no Safari
// e partilhar texto. Nenhuma página da internet é carregada dentro da aplicação.
import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let janela = UIWindow(frame: UIScreen.main.bounds)
        janela.rootViewController = Ecra()
        janela.makeKeyAndVisible()
        window = janela
        return true
    }
}

/// Recusa nomes locais e endereços privados, para a aplicação nunca ser usada para sondar a rede de casa.
func anfitriaoPublico(_ nome: String?) -> Bool {
    guard let host = nome?.lowercased(), !host.isEmpty, host.contains("."),
          !host.hasSuffix(".local"), !host.hasSuffix(".internal") else { return false }
    var pistas = addrinfo()
    pistas.ai_socktype = SOCK_STREAM
    var lista: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(host, nil, &pistas, &lista) == 0, lista != nil else { return false }
    defer { freeaddrinfo(lista) }
    func privado4(_ b: [UInt8]) -> Bool {
        return b[0] == 0 || b[0] == 10 || b[0] == 127 || (b[0] == 169 && b[1] == 254)
            || (b[0] == 172 && (16...31).contains(b[1])) || (b[0] == 192 && b[1] == 168) || b[0] >= 224
    }
    var atual = lista
    while let no = atual {
        if let morada = no.pointee.ai_addr {
            if no.pointee.ai_family == AF_INET {
                let b = morada.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    withUnsafeBytes(of: $0.pointee.sin_addr) { Array($0) }
                }
                if privado4(b) { return false }
            } else if no.pointee.ai_family == AF_INET6 {
                let b = morada.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    withUnsafeBytes(of: $0.pointee.sin6_addr) { Array($0) }
                }
                let zeros = b[0..<10].allSatisfy { $0 == 0 }
                if zeros && b[10] == 0xff && b[11] == 0xff {
                    if privado4(Array(b[12..<16])) { return false }            // ::ffff:a.b.c.d
                } else if zeros && b[10] == 0 && b[11] == 0 {
                    return false                                               // :: e ::1
                } else if b[0] == 0xff || (b[0] & 0xfe) == 0xfc || (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) {
                    return false                                               // multicast, fc00::/7, fe80::/10
                }
            }
        }
        atual = no.pointee.ai_next
    }
    return true
}

/// Os pedidos à rede feitos em nome da página.
final class Rede: NSObject, URLSessionTaskDelegate {
    static let maxBytes = 3 * 1024 * 1024
    static let maxSaltos = 5

    private lazy var sessao: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 25          // prazo para o pedido inteiro, redirecionamentos incluídos
        c.httpMaximumConnectionsPerHost = 4
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.urlCache = nil
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()
    private let versao: String

    init(versao: String) { self.versao = versao }

    /// Pede um endereço. Devolve o estado HTTP e o texto; estado 0 é falha de rede ou pedido recusado.
    func pedir(_ url: URL, feito: @escaping (Int, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard url.scheme == "https", url.user == nil, anfitriaoPublico(url.host) else { return feito(0, "") }
            var pedido = URLRequest(url: url)
            pedido.setValue("DMOS-iOS/\(self.versao) (+https://dmos.cc)", forHTTPHeaderField: "User-Agent")
            pedido.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml, application/json, text/plain, */*",
                            forHTTPHeaderField: "Accept")
            let tarefa = self.sessao.dataTask(with: pedido) { dados, resposta, erro in
                guard erro == nil, let http = resposta as? HTTPURLResponse, let dados = dados,
                      dados.count <= Rede.maxBytes else { return feito(0, "") }
                feito(http.statusCode, Rede.texto(dados, http.textEncodingName))
            }
            tarefa.taskDescription = "0"
            tarefa.resume()
        }
    }

    /// Cada redirecionamento tem de ser HTTPS e para um endereço público, e são no máximo cinco.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let saltos = (Int(task.taskDescription ?? "0") ?? 0) + 1
        task.taskDescription = String(saltos)
        guard saltos <= Rede.maxSaltos, let url = request.url, url.scheme == "https", url.user == nil,
              anfitriaoPublico(url.host) else {
            task.cancel()
            return completionHandler(nil)
        }
        completionHandler(request)
    }

    /// Converte a resposta em texto: o conjunto de caracteres do cabeçalho HTTP, ou da declaração XML, ou UTF-8.
    static func texto(_ dados: Data, _ doCabecalho: String?) -> String {
        var nome = doCabecalho
        if nome == nil, let inicio = String(data: dados.prefix(200), encoding: .isoLatin1),
           let r = inicio.range(of: "<\\?xml[^>]*encoding=[\"'][A-Za-z0-9._-]+[\"']", options: .regularExpression) {
            let declaracao = inicio[r]
            if let v = declaracao.range(of: "encoding=[\"'][A-Za-z0-9._-]+", options: .regularExpression) {
                nome = String(declaracao[v].dropFirst("encoding='".count))
            }
        }
        if let nome = nome {
            let cf = CFStringConvertIANACharSetNameToEncoding(nome as CFString)
            if cf != kCFStringEncodingInvalidId,
               let s = String(data: dados, encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))) {
                return s
            }
        }
        return String(decoding: dados, as: UTF8.self)
    }
}

final class Ecra: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    private var web: WKWebView!
    private let versao = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    private lazy var rede = Rede(versao: versao)
    private var anfitrioes = Set<String>()
    private let pasta = Bundle.main.bundleURL.appendingPathComponent("www", isDirectory: true)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0x0C / 255, green: 0x11 / 255, blue: 0x22 / 255, alpha: 1)
            : UIColor(red: 0xF3 / 255, green: 0xF6 / 255, blue: 0xFA / 255, alpha: 1) }
        carregarAnfitrioes()

        // A ponte: a página encontra «window.DmosNative» com as mesmas funções da aplicação Android.
        // Os pedidos seguem por mensagens; a resposta fica guardada do lado da página até ser recolhida.
        let ponte = """
        (function () {
          var canal = window.webkit.messageHandlers.dmos, prontas = {};
          window.__dmosDeliver = function (id, valor) {
            prontas[id] = valor;
            if (window.__dmosReady) window.__dmosReady(id);
          };
          window.DmosNative = {
            fetch: function (id, url) { canal.postMessage({ a: "fetch", id: String(id), url: String(url) }); },
            take: function (id) { var v = prontas[id]; delete prontas[id]; return v || ""; },
            open: function (url) { canal.postMessage({ a: "open", url: String(url) }); },
            share: function (texto) { canal.postMessage({ a: "share", text: String(texto) }); },
            version: function () { return \(Ecra.json(versao)); },
            allowSource: function (endereco) {
              try {
                var u = new URL(String(endereco));
                if (String(endereco).length > 500 || u.protocol !== "https:" || u.username || u.password) return false;
                var h = u.hostname.toLowerCase();
                if (!/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/.test(h) || /^[0-9.]+$/.test(h)) return false;
                canal.postMessage({ a: "allow", host: h });
                return true;
              } catch (e) { return false; }
            }
          };
        })();
        """
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController.addUserScript(WKUserScript(source: ponte, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(Fraco(self), name: "dmos")

        web = WKWebView(frame: view.bounds, configuration: config)
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        web.navigationDelegate = self
        web.uiDelegate = self
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        // A página trata das margens seguras (entalhe e barra inferior) com env(safe-area-inset-*).
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsBackForwardNavigationGestures = true
        web.allowsLinkPreview = false
        view.addSubview(web)
        web.loadFileURL(pasta.appendingPathComponent("index.html"), allowingReadAccessTo: pasta)
    }

    /// Os anfitriões a que a página pode fazer pedidos: o site do DMOS, o repositório, as fontes do
    /// DMOS Hub (www/data/sources.json) e as fontes que o utilizador acrescentou.
    private func carregarAnfitrioes() {
        anfitrioes = ["dmos.cc", "raw.githubusercontent.com"]
        if let dados = try? Data(contentsOf: pasta.appendingPathComponent("data/sources.json")),
           let lista = try? JSONSerialization.jsonObject(with: dados) as? [[String: Any]] {
            for fonte in lista {
                if let texto = fonte["url"] as? String, let host = URL(string: texto)?.host { anfitrioes.insert(host.lowercased()) }
            }
        }
        anfitrioes.formUnion(UserDefaults.standard.stringArray(forKey: "fontes") ?? [])
    }

    private static func json(_ valor: String) -> String {
        let dados = (try? JSONSerialization.data(withJSONObject: [valor])) ?? Data("[\"\"]".utf8)
        return String(String(decoding: dados, as: UTF8.self).dropFirst().dropLast())
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Só a página local, na moldura principal, pode usar a ponte.
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.isFileURL == true,
              let corpo = message.body as? [String: Any], let acao = corpo["a"] as? String else { return }
        switch acao {
        case "fetch":
            guard let id = corpo["id"] as? String, id.range(of: "^[A-Za-z0-9_-]{1,40}$", options: .regularExpression) != nil else { return }
            guard let texto = corpo["url"] as? String, let url = URL(string: texto), let host = url.host?.lowercased(),
                  anfitrioes.contains(host) else { return entregar(id, 0, "") }
            rede.pedir(url) { [weak self] estado, texto in
                DispatchQueue.main.async { self?.entregar(id, estado, texto) }
            }
        case "open":
            if let texto = corpo["url"] as? String { abrirFora(URL(string: texto)) }
        case "share":
            guard let texto = corpo["text"] as? String, texto.count <= 2000 else { return }
            let folha = UIActivityViewController(activityItems: [texto], applicationActivities: nil)
            folha.popoverPresentationController?.sourceView = view
            folha.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            present(folha, animated: true)
        case "allow":
            guard let host = corpo["host"] as? String, host.count <= 253,
                  host.range(of: "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", options: .regularExpression) != nil,
                  host.range(of: "^[0-9.]+$", options: .regularExpression) == nil else { return }
            if anfitrioes.insert(host).inserted {
                var guardados = UserDefaults.standard.stringArray(forKey: "fontes") ?? []
                guardados.append(host)
                UserDefaults.standard.set(guardados, forKey: "fontes")
            }
        default:
            break
        }
    }

    /// Entrega à página a resposta de um pedido, como «estado,textoEmBase64».
    private func entregar(_ id: String, _ estado: Int, _ texto: String) {
        let valor = "\(estado)," + Data(texto.utf8).base64EncodedString()
        web.evaluateJavaScript("window.__dmosDeliver(\(Ecra.json(id)), \(Ecra.json(valor)))", completionHandler: nil)
    }

    private func abrirFora(_ url: URL?) {
        guard let url = url, url.scheme == "https" || url.scheme == "http" else { return }
        UIApplication.shared.open(url)
    }

    // A WebView só mostra a página local; qualquer outra ligação abre no Safari.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
        if url.isFileURL && url.resolvingSymlinksInPath().path.hasPrefix(pasta.resolvingSymlinksInPath().path + "/") { return decisionHandler(.allow) }
        if navigationAction.targetFrame?.isMainFrame != false { abrirFora(url) }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        abrirFora(navigationAction.request.url)
        return nil
    }

    // Se o sistema terminar o processo da página para libertar memória, volta a carregá-la.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.loadFileURL(pasta.appendingPathComponent("index.html"), allowingReadAccessTo: pasta)
    }

    #if targetEnvironment(simulator)
    // Só no simulador, para o teste automático (.github/workflows/ios.yml): depois de a página
    // carregar, abre as notícias, liga três fontes, espera e escreve em Documents/teste.json o que a página mostra.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard ProcessInfo.processInfo.environment["DMOS_TESTE"] == "1" else { return }
        let destino = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("teste.json")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            webView.evaluateJavaScript("location.hash = 'noticias'; 1", completionHandler: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            webView.evaluateJavaScript("Array.prototype.slice.call(document.querySelectorAll('#fontes button'), 0, 3).forEach(function (b) { b.click(); }); 1", completionHandler: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            let js = """
            (function () {
              var guardou = false;
              try { localStorage.setItem("dmos.teste", "1"); guardou = localStorage.getItem("dmos.teste") === "1"; } catch (e) {}
              return JSON.stringify({
                ponte: !!window.DmosNative, versaoApp: window.DmosNative ? window.DmosNative.version() : "",
                versaoDmos: document.getElementById("versao-nome").textContent,
                novidades: document.getElementById("versao-novidades").children.length,
                sha256: document.getElementById("sha256").textContent,
                fontes: document.getElementById("fontes").children.length,
                noticias: document.getElementById("noticias").children.length,
                estado: document.getElementById("noticias-estado").textContent,
                primeira: (document.querySelector("#noticias a, #noticias h3, #noticias button") || {}).textContent || "",
                videos: document.getElementById("videos").children.length,
                memoria: guardou, estilo: getComputedStyle(document.querySelector(".abas")).position
              });
            })()
            """
            webView.evaluateJavaScript(js) { resultado, erro in
                let texto = (resultado as? String) ?? "{\"erro\": \(Ecra.json(erro?.localizedDescription ?? "sem resultado"))}"
                try? texto.write(to: destino, atomically: true, encoding: .utf8)
            }
        }
    }
    #endif
}

/// Evita o ciclo de referências entre a WebView e o ecrã.
final class Fraco: NSObject, WKScriptMessageHandler {
    private weak var alvo: WKScriptMessageHandler?
    init(_ alvo: WKScriptMessageHandler) { self.alvo = alvo }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        alvo?.userContentController(userContentController, didReceive: message)
    }
}
