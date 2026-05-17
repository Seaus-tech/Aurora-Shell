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

async function listMeetings() {
    const now = new Date().toISOString();
    const end = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const data = await graph(`/me/calendarView?startDateTime=${now}&endDateTime=${end}&$top=10&$orderby=start/dateTime`);
    console.log(chalk.cyan('\n📅 Upcoming Meetings:\n'));
    if (!data.value.length) { console.log(chalk.gray('  No upcoming meetings')); return; }
    data.value.forEach((event, i) => {
        const start = new Date(event.start.dateTime).toLocaleString();
        const isOnline = event.isOnlineMeeting ? chalk.green('🎥 Online') : chalk.gray('📍 In-person');
        console.log(`  ${i + 1}. ${chalk.bold(event.subject)}`);
        console.log(`     ${chalk.gray(start)} ${isOnline}`);
        if (event.onlineMeeting?.joinUrl) console.log(`     ${chalk.blue(event.onlineMeeting.joinUrl)}`);
    });
}

async function createMeeting(subject, startTime, endTime) {
    const data = await graph('/me/onlineMeetings', 'POST', {
        subject,
        startDateTime: new Date(startTime).toISOString(),
        endDateTime: new Date(endTime).toISOString()
    });
    console.log(chalk.green(`✅ Meeting "${subject}" created`));
    console.log(chalk.blue(`   Join: ${data.joinWebUrl}`));
}

const STATUS_MAP = {
    available: 'Available',
    busy: 'Busy',
    dnd: 'DoNotDisturb',
    away: 'Away',
    offline: 'Offline',
    brb: 'BeRightBack'
};

async function setStatus(status, message = '') {
    const activity = STATUS_MAP[status.toLowerCase()];
    if (!activity) {
        console.log(chalk.red(`❌ Invalid status. Use: ${Object.keys(STATUS_MAP).join(', ')}`));
        return;
    }
    const me = await graph('/me');
    await graph(`/users/${me.id}/presence/setPresence`, 'POST', {
        sessionId: 'teams-cli',
        availability: activity,
        activity,
        expirationDuration: 'PT1H'
    });
    if (message) {
        await graph('/me/presence/setStatusMessage', 'POST', {
            statusMessage: { message: { content: message, contentType: 'text' } }
        });
    }
    console.log(chalk.green(`✅ Status set to ${activity}${message ? ` - "${message}"` : ''}`));
}

async function getStatus(userId = 'me') {
    const data = await graph(`/${userId}/presence`);
    const emoji = { Available: '🟢', Busy: '🔴', DoNotDisturb: '⛔', Away: '🟡', Offline: '⚫', BeRightBack: '🟠' };
    console.log(`${emoji[data.availability] || '⚪'} ${chalk.bold(data.availability)} - ${data.activity}`);
}

module.exports = { listMeetings, createMeeting, setStatus, getStatus };
