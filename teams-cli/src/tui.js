const blessed = require('blessed');
const { ensureToken: getToken } = require('./auth');

async function graph(path, method = 'GET', body = null) {
    const token = await getToken();
    const res = await fetch(`https://graph.microsoft.com/v1.0${path}`, {
        method,
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : null
    });
    if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
    return method === 'GET' ? res.json() : null;
}

async function openChat(chatId) {
    // Get chat info
    const [chatInfo, me] = await Promise.all([
        graph(`/me/chats/${chatId}?$expand=members`),
        graph('/me')
    ]);

    const chatName = chatInfo.topic ||
        chatInfo.members?.map(m => m.displayName).filter(n => n !== me.displayName).join(', ') ||
        'Chat';

    // Build screen
    const screen = blessed.screen({ smartCSR: true, title: `Teams - ${chatName}` });

    // Header
    const header = blessed.box({
        top: 0, left: 0, width: '100%', height: 3,
        content: ` 💬 ${chatName}  {gray-fg}[ESC to exit]{/gray-fg}`,
        tags: true,
        style: { bg: '#6264a7', fg: 'white', bold: true }
    });

    // Messages area
    const msgBox = blessed.log({
        top: 3, left: 0, width: '100%', height: '100%-6',
        scrollable: true, alwaysScroll: true,
        tags: true, wrap: true,
        scrollbar: { ch: '│', style: { fg: '#6264a7' } },
        style: { bg: '#1e1e1e', fg: 'white' },
        padding: { left: 1, right: 1 }
    });

    // Input bar
    const inputBar = blessed.textbox({
        bottom: 0, left: 0, width: '100%-10', height: 3,
        inputOnFocus: true,
        style: { bg: '#2d2d2d', fg: 'white', focus: { bg: '#3d3d3d' } },
        border: { type: 'line', fg: '#6264a7' },
        padding: { left: 1 }
    });

    // Send button
    const sendBtn = blessed.button({
        bottom: 0, right: 0, width: 10, height: 3,
        content: ' Send ▶',
        style: { bg: '#6264a7', fg: 'white', hover: { bg: '#7b7dc4' } },
        border: { type: 'line', fg: '#6264a7' }
    });

    // Status bar
    const statusBar = blessed.box({
        bottom: 3, left: 0, width: '100%', height: 1,
        content: ' ● Connected  {gray-fg}↑↓ scroll  Enter send  ESC exit{/gray-fg}',
        tags: true,
        style: { bg: '#6264a7', fg: 'white' }
    });

    screen.append(header);
    screen.append(msgBox);
    screen.append(statusBar);
    screen.append(inputBar);
    screen.append(sendBtn);

    // Load messages
    const renderMessages = async () => {
        const data = await graph(`/me/chats/${chatId}/messages?$top=30`);
        msgBox.setContent('');
        data.value.reverse().forEach(msg => {
            const sender = msg.from?.user?.displayName || 'Unknown';
            const time = new Date(msg.createdDateTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            const content = msg.body?.content?.replace(/<[^>]*>/g, '').trim() || '';
            if (!content) return;
            const isMe = msg.from?.user?.id === me.id;
            const nameColor = isMe ? '{#7b7dc4-fg}' : '{#6264a7-fg}';
            msgBox.log(`{gray-fg}${time}{/gray-fg} ${nameColor}${sender}{/} : ${content}`);
        });
        screen.render();
    };

    await renderMessages();

    // Send message
    const sendMessage = async () => {
        const text = inputBar.getValue().trim();
        if (!text) return;
        inputBar.clearValue();
        screen.render();
        try {
            await graph(`/me/chats/${chatId}/messages`, 'POST', {
                body: { content: text, contentType: 'text' }
            });
            await renderMessages();
        } catch (e) {
            msgBox.log(`{red-fg}Error: ${e.message}{/red-fg}`);
            screen.render();
        }
    };

    inputBar.key('enter', sendMessage);
    sendBtn.on('press', sendMessage);

    // Poll for new messages every 5s
    const poll = setInterval(renderMessages, 5000);

    // Exit
    screen.key(['escape', 'q', 'C-c'], () => {
        clearInterval(poll);
        screen.destroy();
        process.exit(0);
    });

    inputBar.focus();
    screen.render();
}

module.exports = { openChat };
