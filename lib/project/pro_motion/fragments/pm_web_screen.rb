# Finding it more and more easy to just derive from PMScreen
class PMWebScreen < PMScreen
  attr_accessor :webview

  def screen_setup
    web_view_setup
  end

  def web_view_setup
    # SPECIAL NOTE: Must create from activity, not from context (breaks dialogs)
    @webview = Android::Webkit::WebView.new(find.activity)
    append(@webview)
    settings = @webview.settings
    settings.savePassword = true
    settings.saveFormData = true
    settings.javaScriptEnabled = true
    settings.supportZoom = false

    # By default some URLs try to launch a browser. Very unlikely that this is
    # the behaviour we'll want in an app.   So we use this to stop
    #@webview.webViewClient = PMWebClient.new

    accept_cookies
  end

  def open_url(url)
    @webview.loadUrl(url)
  end

  def accept_cookies(accept_cookies=true)
    cookie_manager = Android::Webkit::CookieManager.getInstance()
    cookie_manager.acceptCookie = accept_cookies
  end

  def web
    self.webView
  end

  def url=(url_str)
    self.webView.loadUrl(url_str)
  end

end