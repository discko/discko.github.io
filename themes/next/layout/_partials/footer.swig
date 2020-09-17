{%- if theme.footer.beian.enable %}
  <div class="beian">
    {{- next_url('http://beian.miit.gov.cn', theme.footer.beian.icp + ' ') }}
    {%- if theme.footer.beian.gongan_icon_url %}
      <img src="{{ url_for(theme.footer.beian.gongan_icon_url) }}" style="display: inline-block;">
    {%- endif %}
    {%- if theme.footer.beian.gongan_id and theme.footer.beian.gongan_num %}
      {{- next_url('http://www.beian.gov.cn/portal/registerSystemInfo?recordcode=' + theme.footer.beian.gongan_id, theme.footer.beian.gongan_num + ' ') }}
    {%- endif %}
  </div>
{%- endif %}

<div class="copyright">
  {% set copyright_year = date(null, 'YYYY') %}
  &copy; {% if theme.footer.since and theme.footer.since != copyright_year %}{{ theme.footer.since }} – {% endif %}
  <span itemprop="copyrightYear">{{ copyright_year }}</span>
  <span class="with-love">
    <i class="{{ theme.footer.icon.name }}"></i>
  </span>
  <span class="author" itemprop="copyrightHolder">{{ theme.footer.copyright or author }}</span>

  {%- if config.symbols_count_time.total_symbols %}
    <span class="post-meta-divider">|</span>
    <span class="post-meta-item-icon">
      <i class="fa fa-chart-area"></i>
    </span>
    {%- if theme.symbols_count_time.item_text_total %}
      <span class="post-meta-item-text">{{ __('symbols_count_time.count_total') + __('symbol.colon') }}</span>
    {%- endif %}
    <span title="{{ __('symbols_count_time.count_total') }}">{{ symbolsCountTotal(site) }}</span>
  {%- endif %}

  {%- if config.symbols_count_time.total_time %}
    <span class="post-meta-divider">|</span>
    <span class="post-meta-item-icon">
      <i class="fa fa-coffee"></i>
    </span>
    {%- if theme.symbols_count_time.item_text_total %}
      <span class="post-meta-item-text">{{ __('symbols_count_time.time_total') }} &asymp;</span>
    {%- endif %}
    <span title="{{ __('symbols_count_time.time_total') }}">{{ symbolsTimeTotal(site, config.symbols_count_time.awl, config.symbols_count_time.wpm, __('symbols_count_time.time_minutes')) }}</span>
  {%- endif %}
</div>

{%- if theme.footer.powered %}
  <div class="powered-by">
    {%- set next_site = 'https://theme-next.org' %}
    {%- if theme.scheme !== 'Gemini' %}
      {%- set next_site = 'https://' + theme.scheme | lower + '.theme-next.org' %}
    {%- endif %}
    {{- __('footer.powered', next_url('https://hexo.io', 'Hexo', {class: 'theme-link'}) + ' & ' + next_url(next_site, 'NexT.' + theme.scheme, {class: 'theme-link'})) }}
  </div>
{%- endif %}

{%- if theme.add_this_id %}
  <div class="addthis_inline_share_toolbox">
    <script src="//s7.addthis.com/js/300/addthis_widget.js#pubid={{ theme.add_this_id }}" async="async"></script>
  </div>
{%- endif %}

{{- next_inject('footer') }}

{% if theme.mermaid.enable %}
  <script src='https://unpkg.com/mermaid@7.1.2/dist/mermaid.min.js'></script>
  <script>
    if (window.mermaid) {
      var config = {
        theme:'default',
        logLevel:'fatal',
        securityLevel:'strict',
        startOnLoad:true,
        arrowMarkerAbsolute:false,

        er:{
          diagramPadding:20,
          layoutDirection:'TB',
          minEntityWidth:100,
          minEntityHeight:75,
          entityPadding:15,
          stroke:'gray',
          fill:'honeydew',
          fontSize:12,
          useMaxWidth:true,
        },
        flowchart:{
          diagramPadding:8,
          htmlLabels:true,
          curve:'linear',
        },
        sequence:{
          diagramMarginX:50,
          diagramMarginY:10,
          actorMargin:50,
          width:150,
          height:65,
          boxMargin:10,
          boxTextMargin:5,
          noteMargin:10,
          messageMargin:35,
          messageAlign:'center',
          mirrorActors:true,
          bottomMarginAdj:1,
          useMaxWidth:true,
          rightAngles:false,
          showSequenceNumbers:false,
        },
        gantt:{
          titleTopMargin:25,
          barHeight:20,
          barGap:4,
          topPadding:50,
          leftPadding:75,
          gridLineStartPadding:35,
          fontSize:11,
          fontFamily:'"Open-Sans", "sans-serif"',
          numberSectionStyles:4,
          axisFormat:'%Y-%m-%d',
        }
      };
      mermaid.initialize(config);
    }
  </script>
{% endif %}