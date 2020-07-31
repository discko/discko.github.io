# REMEMBER TO EDIT THE NODE_MODULES FILES
following sections are the tips for fixing the bugs of hexo plugins.
## 1. hexo-asset-image
edit `node_modules/hexo-asset-image/index.js`:
```js
    if(/.*\/index\.html$/.test(link)) {
      appendLink = 'index/';
      var endPos = link.lastIndexOf('/');
    }
    else {
      // var endPos = link.lastIndexOf('.');
      var endPos = link.length-1;
    }
```

## 2. hexo-renderer-kramed
edit `node_modules/kramed/lib/rules/inline.js`:   
```js
// escape: /^\\([\\`*{}\[\]()#$+\-.!_>])/,
  escape: /^\\([`*\[\]()#$+\-.!_>])/,
// em: /^\b_((?:__|[\s\S])+?)_\b|^\*((?:\*\*|[\s\S])+?)\*(?!\*)/,
  em: /^\*((?:\*\*|[\s\S])+?)\*(?!\*)/,
```