const { ensureToken: getToken } = require('./auth');
const chalk = require('chalk');

async function graph(path, method = 'GET', body = null) {
    const token = await getToken();
    const res = await fetch(`https://graph.microsoft.com/v1.0${path}`, {
        method,
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : null
    });
    if (!res.ok) throw new Error(`Graph API error: ${res.status} ${await res.text()}`);
    return method === 'GET' ? res.json() : res;
}

async function listChats() {
    const data = await graph('/me/chats?$expand=members&$top=20');
    console.log(chalk.cyan('\n💬 Your Chats:\n'));
    data.value.forEach((chat, i) => {
        const name = chat.topic || chat.members?.map(m => m.displayName).filter(Boolean).join(', ') || 'Unknown';
        console.log(chalk.white(`  ${i + 1}. ${chalk.bold(name)} ${chalk.gray(`[${chat.id}]`)}`));
    });
}

async function sendChat(chatId, message) {
    await graph(`/me/chats/${chatId}/messages`, 'POST', {
        body: { content: message, contentType: 'text' }
    });
    console.log(chalk.green('✅ Message sent'));
}

async function readChat(chatId, limit = 10) {
    const data = await graph(`/me/chats/${chatId}/messages?$top=${limit}`);
    console.log(chalk.cyan('\n📨 Messages:\n'));
    data.value.reverse().forEach(msg => {
        const sender = msg.from?.user?.displayName || 'Unknown';
        const time = new Date(msg.createdDateTime).toLocaleTimeString();
        const content = msg.body?.content?.replace(/<[^>]*>/g, '') || '';
        console.log(`  ${chalk.gray(time)} ${chalk.bold.cyan(sender)}: ${content}`);
    });
}

module.exports = { listChats, sendChat, readChat };
