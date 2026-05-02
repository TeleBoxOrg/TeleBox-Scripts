// @ts-ignore: KV is injected by Cloudflare Workers runtime
const kv = KV;

const TELEGRAPH_TOKEN = '';
const PLUGINS_JSON_URL = 'https://raw.githubusercontent.com/TeleBoxDev/TeleBox_Plugins/main/plugins.json';
const PLUGINS_REPO_URL = 'https://github.com/TeleBoxDev/TeleBox_Plugins';

// Telegraph API
async function createTelegraphPage(title, content) {
  const response = await fetch('https://api.telegra.ph/createPage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      access_token: TELEGRAPH_TOKEN,
      title: title,
      author_name: 'Telebox插件仓库',
      author_url: PLUGINS_REPO_URL,
      content: content,
      return_content: false
    })
  });
  const data = await response.json();
  if (data.ok && data.result) {
    return { url: data.result.url, path: data.result.path };
  }
  return null;
}

async function editTelegraphPage(path, title, content) {
  const response = await fetch('https://api.telegra.ph/editPage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      access_token: TELEGRAPH_TOKEN,
      path: path,
      title: title,
      author_name: 'Telebox插件仓库',
      author_url: PLUGINS_REPO_URL,
      content: content,
      return_content: false
    })
  });
  const data = await response.json();
  if (data.ok && data.result) {
    return { url: data.result.url, path: data.result.path };
  }
  return null;
}

// HTML 清理工具：移除所有标签，仅保留纯文本
function cleanDescription(text) {
  if (!text) return '';
  // 解码 HTML 实体
  let cleaned = text
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
  // 移除所有 HTML 标签
  cleaned = cleaned.replace(/<[^>]+>/g, '');
  // 清理多余空白（保留单个空格和换行）
  cleaned = cleaned.replace(/\s+/g, ' ').trim();
  return cleaned;
}

// 从 plugins.json 解析插件
function parsePluginsJson(pluginsJson) {
  const plugins = [];
  for (const [key, data] of Object.entries(pluginsJson)) {
    const name = key.trim();
    const url = (data.url || '').trim();
    const desc = cleanDescription((data.desc || '暂无描述').trim());
    if (name) {
      plugins.push({
        name: name,
        description: desc,
        url: url,
        // 生成插件源代码链接
        sourceUrl: `${PLUGINS_REPO_URL}/tree/main/plugins/${encodeURIComponent(name)}`
      });
    }
  }
  return plugins.sort((a, b) => a.name.localeCompare(b.name));
}

// 生成美化后的 Telegraph 内容（修改点：时间/统计分别放入 blockquote，安装提示改为“使用 .tpm i xxx 安装该插件”）
function generateTelegraphContent(plugins) {
  const now = new Date();
  // 强制使用上海时区
  const formattedTime = now.toLocaleString('zh-CN', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });

  const content = [];
  
  // 最后更新时间（放入 blockquote）
  content.push({
    tag: 'blockquote',
    children: [
      { tag: 'span', attrs: { style: 'color:#9e9e9e' }, children: ['⏰ 最后更新于 '] },
      { tag: 'span', attrs: { style: 'color:#1e88e5' }, children: [formattedTime] }
    ]
  });
  
  // 插件数量统计（放入 blockquote）
  content.push({
    tag: 'blockquote',
    children: [
      { tag: 'span', attrs: { style: 'color:#1e88e5' }, children: ['🧩'] },
      { tag: 'span', attrs: { style: 'color:#1e88e5' }, children: [` 共 ${plugins.length} 个插件`] }
    ]
  });
  
  content.push({ tag: 'hr' });
  
  // 插件列表
  plugins.forEach((plugin, index) => {
    // 插件标题（带序号和装饰，插件名添加超链接）
    content.push({ 
      tag: 'h4', 
      children: [
        { tag: 'span', attrs: { style: 'color:#1e88e5' }, children: ['✦ '] },
        {
          tag: 'a',
          attrs: { href: plugin.sourceUrl, style: 'color:#1e88e5;text-decoration:none' },
          children: [plugin.name]
        }
      ] 
    });
    
    // 插件描述（带引用样式）
    content.push({ 
      tag: 'blockquote',
      children: [plugin.description || '暂无描述']
    });
    
    // 安装命令（修改为“使用 .tpm i xxx 安装该插件”）
    content.push({
      tag: 'p',
      children: [
        { tag: 'strong', children: ['使用 '] },
        { 
          tag: 'code', 
          children: [`.tpm i ${plugin.name}`] 
        },
        { tag: 'strong', children: [' 安装该插件'] }
      ]
    });
    
    // 分隔线（最后一个插件后不加）
    if (index < plugins.length - 1) {
      content.push({ 
        tag: 'div', 
        attrs: { style: 'height:12px' } 
      });
    }
  });
  
  return content;
}

// 数据获取
async function fetchPluginsJson() {
  const response = await fetch(PLUGINS_JSON_URL);
  if (!response.ok) {
    throw new Error(`Failed to fetch plugins.json: ${response.status}`);
  }
  const data = await response.json();
  return parsePluginsJson(data);
}

// 同步并发布到 Telegraph
async function syncAndPublish() {
  try {
    console.log('🔄 开始同步插件数据...');
    const plugins = await fetchPluginsJson();
    console.log(`✅ 获取到 ${plugins.length} 个插件`);
    
    // 生成 Telegraph 内容
    const content = generateTelegraphContent(plugins);
    
    // 检查是否已有页面
    const savedPath = await kv.get('telegraph_main_path');
    
    let result;
    if (savedPath) {
      result = await editTelegraphPage(savedPath, '📚 TeleBox 插件列表', content);
      console.log(`✅ 已更新现有页面：${result?.url || '未知'}`);
    } else {
      result = await createTelegraphPage('📚 TeleBox 插件列表', content);
      console.log(`✅ 已创建新页面：${result?.url || '未知'}`);
    }
    
    if (result) {
      // 保存到 KV
      await kv.put('telegraph_main_path', result.path);
      await kv.put('telegraph_main_url', result.url);
      await kv.put('plugin_count', plugins.length.toString());
      await kv.put('last_update', new Date().toISOString());
      
      console.log(`✅ 同步完成：${plugins.length} 个插件`);
      return { 
        success: true, 
        url: result.url, 
        count: plugins.length,
        timestamp: new Date().toISOString()
      };
    } else {
      throw new Error('Telegraph API 返回失败');
    }
  } catch (error) {
    console.error('❌ 同步失败:', error);
    return { 
      success: false, 
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}

// HTTP 路由
async function handleRequest(request) {
  const url = new URL(request.url);
  const path = url.pathname;
  
  // 健康检查
  if (path === '/') {
    return new Response(JSON.stringify({
      status: 'ok',
      service: 'TeleBox Plugin Index',
      endpoints: {
        '/get': 'GET - 返回最新 Telegraph 链接',
        '/sync': 'GET - 手动触发更新'
      }
    }, null, 2), {
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  // 获取最新链接
  if (path === '/get') {
    const telegraphUrl = await kv.get('telegraph_main_url');
    const pluginCount = await kv.get('plugin_count');
    const lastUpdate = await kv.get('last_update');
    
    if (!telegraphUrl) {
      return new Response(JSON.stringify({
        success: false,
        error: '插件列表尚未生成，请先访问 /sync 触发更新'
      }, null, 2), {
        status: 404,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }
    
    return new Response(JSON.stringify({
      success: true,
      url: telegraphUrl,
      count: parseInt(pluginCount) || 0,
      last_update: lastUpdate || null,
      timestamp: new Date().toISOString()
    }, null, 2), {
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  // 手动同步
  if (path === '/sync') {
    const result = await syncAndPublish();
    return new Response(JSON.stringify(result, null, 2), {
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  // 404
  return new Response(JSON.stringify({
    error: 'Not found',
    available_endpoints: ['/get', '/sync']
  }, null, 2), {
    status: 404,
    headers: { 
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

// 定时任务：每小时自动更新
async function handleScheduled(event) {
  console.log('⏰ 定时任务触发:', event.scheduledTime.toISOString());
  await syncAndPublish();
}

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

addEventListener('scheduled', event => {
  event.waitUntil(handleScheduled(event));
});