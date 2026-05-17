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

async function listTeams() {
    const data = await graph('/me/joinedTeams');
    console.log(chalk.cyan('\n👥 Your Teams:\n'));
    data.value.forEach((team, i) => {
        console.log(`  ${i + 1}. ${chalk.bold(team.displayName)} ${chalk.gray(`[${team.id}]`)}`);
        if (team.description) console.log(`     ${chalk.gray(team.description)}`);
    });
}

async function listChannels(teamId) {
    const data = await graph(`/teams/${teamId}/channels`);
    console.log(chalk.cyan('\n📢 Channels:\n'));
    data.value.forEach((ch, i) => {
        console.log(`  ${i + 1}. ${chalk.bold(ch.displayName)} ${chalk.gray(`[${ch.id}]`)}`);
    });
}

async function sendChannel(teamId, channelId, message) {
    await graph(`/teams/${teamId}/channels/${channelId}/messages`, 'POST', {
        body: { content: message, contentType: 'text' }
    });
    console.log(chalk.green('✅ Message sent to channel'));
}

async function readChannel(teamId, channelId, limit = 10) {
    const data = await graph(`/teams/${teamId}/channels/${channelId}/messages?$top=${limit}`);
    console.log(chalk.cyan('\n📨 Channel Messages:\n'));
    data.value.reverse().forEach(msg => {
        const sender = msg.from?.user?.displayName || 'Unknown';
        const time = new Date(msg.createdDateTime).toLocaleTimeString();
        const content = msg.body?.content?.replace(/<[^>]*>/g, '') || '';
        console.log(`  ${chalk.gray(time)} ${chalk.bold.cyan(sender)}: ${content}`);
    });
}

async function createTeam(name, description = '') {
    const data = await graph('/teams', 'POST', {
        'template@odata.bind': "https://graph.microsoft.com/v1.0/teamsTemplates('standard')",
        displayName: name,
        description
    });
    console.log(chalk.green(`✅ Team "${name}" created`));
}

module.exports = { listTeams, listChannels, sendChannel, readChannel, createTeam };
