/**
 * 更新邀请链接的简单方法
 * 查找页面中的邀请链接，通过.json接口获取inner_invite_link并替换
 */

async function updateInviteLinks() {
    // 定义需要处理的邀请链接模式
    const invitePatterns = [
        'https://rebateto.me/invite_links/binance',
        'https://rebateto.me/invite_links/okx',
        'https://rebateto.me/invite_links/gateio'
    ];

    // 为每个邀请链接模式处理
    for (const baseUrl of invitePatterns) {
        try {
            // 构建JSON接口URL
            const jsonUrl = baseUrl + '.json';

            // 发送请求获取数据
            const response = await fetch(jsonUrl, {
                method: 'GET',
                mode: 'cors',
                credentials: 'omit',
                headers: { 'Accept': 'application/json' },
                cache: 'no-store'
            });
            if (!response.ok) {
                console.warn(`Failed to fetch ${jsonUrl}: ${response.status}`);
                return;
            }

            const data = await response.json();

            // 检查是否有inner_invite_link字段
            if (data && data.inner_invite_link) {
                const newUrl = data.inner_invite_link;
                console.log(`Updating ${baseUrl} to ${newUrl}`);

                // 替换页面中所有的链接
                replaceLinksInPage(baseUrl, newUrl);
            } else {
                console.warn(`No inner_invite_link found in response from ${jsonUrl}`);
            }
        } catch (error) {
            console.error(`Error processing ${baseUrl}:`, error);
        }
    }
}

/**
 * 在页面中替换指定链接
 * @param {string} oldUrl - 要替换的旧链接
 * @param {string} newUrl - 新的链接
 */
function replaceLinksInPage(oldUrl, newUrl) {
    // 替换所有a标签中的href
    const links = document.querySelectorAll('a[href]');
    links.forEach(link => {
        if (link.href === oldUrl) {
            link.href = newUrl;
        }
    });

    // 替换文本内容中的链接
    const walker = document.createTreeWalker(
        document.body,
        NodeFilter.SHOW_TEXT,
        null,
        false
    );

    const textNodes = [];
    let node;
    while (node = walker.nextNode()) {
        textNodes.push(node);
    }

    textNodes.forEach(textNode => {
        if (textNode.textContent.includes(oldUrl)) {
            textNode.textContent = textNode.textContent.replace(
                new RegExp(oldUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'),
                newUrl
            );
        }
    });
}

// 页面加载完成后自动执行
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', updateInviteLinks);
} else {
    updateInviteLinks();
}

// 导出函数供手动调用
window.updateInviteLinks = updateInviteLinks;
