#!/usr/bin/env node
const { program } = require('commander');
const chalk = require('chalk');
const { ensureToken, login, logout, whoami } = require('./auth');
const { listChats, sendChat, readChat } = require('./chat');
const { listTeams, listChannels, sendChannel, readChannel, createTeam } = require('./teams');
const { listMeetings, createMeeting, setStatus, getStatus } = require('./meetings');
const { openChat } = require('./tui');

const b = (s) => chalk.hex('#6264a7')(s);
const lb = (s) => chalk.hex('#9ea2e8')(s);

const LOGO = `
  ${lb('⠀⠀⠀⠀⢀⣴⣾⣿⣿⣷⣦⡀⠀⠀⠀⠀')}
  ${lb('⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣦⠀⠀⠀')}
  ${lb('⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⠀')}
  ${lb('⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠀⠀')}  ${b('⠀⢀⣴⣾⣷⣦⡀')}
  ${b('⠀⣀⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣀⠀')}  ${b('⠀⣾⣿⣿⣿⣿⣿⣷')}
  ${b('⣾⣿⣿⣿')}${chalk.white('⣿⣿⣿⣿⣿⣿⣿⣿')}${b('⣿⣿⣷')} ${b('⣿⣿⣿⣿⣿⣿⣿⣿')}
  ${b('⣿⣿⣿⣿')}${chalk.white('⣿⣿')}${chalk.bold.white(' T ')}${chalk.white('⣿⣿⣿⣿⣿')}${b('⣿⣿⣿')} ${b('⣿⣿⣿⣿⣿⣿⣿⣿')}
  ${b('⣿⣿⣿⣿')}${chalk.white('⣿⣿⣿⣿⣿⣿⣿⣿')}${b('⣿⣿⣷')} ${b('⣿⣿⣿⣿⣿⣿⣿⣿')}
  ${b('⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇')}  ${b('⠸⣿⣿⣿⣿⣿⣿⠇')}
  ${b('⠀⠙⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠋⠀')}  ${b('⠀⠙⠻⣿⣿⠟⠋')}

  ${chalk.bold.hex('#6264a7')('Microsoft Teams CLI')} ${chalk.gray('v1.0.0 — Aurora Shell')}
`;

if (process.stdout.isTTY && !process.argv.includes('--no-logo')) {
    console.log(LOGO);
}

const handle = (fn) => (...args) => fn(...args).catch(e => console.error(chalk.red('❌ ' + e.message)));

program
    .name('teams')
    .description('Aurora Shell - Microsoft Teams CLI')
    .version('1.0.0');

// Auth
program.command('login').description('Login to Microsoft Teams').action(handle(async () => {
    const token = await login();
    console.log(chalk.green(`✅ Logged in successfully!`));
}));
program.command('logout').description('Logout').action(handle(logout));
program.command('whoami').description('Show current user').action(handle(async () => {
    const me = await whoami();
    console.log(`${chalk.bold(me.displayName)} <${me.mail || me.userPrincipalName}>`);
}));

// Chat
const chat = program.command('chat').description('Chat commands');
chat.command('list').description('List chats').action(handle(listChats));
chat.command('open <chatId>').description('Open chat TUI interface').action(handle(openChat));
chat.command('read <chatId>').description('Read messages').option('-n, --limit <n>', 'number of messages', '10')
    .action(handle((id, opts) => readChat(id, parseInt(opts.limit))));
chat.command('send <chatId> <message>').description('Send a message').action(handle(sendChat));

// Teams
const teams = program.command('teams').description('Teams commands');
teams.command('list').description('List your teams').action(handle(listTeams));
teams.command('create <name> [description]').description('Create a team').action(handle(createTeam));

// Channels
const channels = program.command('channels').description('Channel commands');
channels.command('list <teamId>').description('List channels').action(handle(listChannels));
channels.command('read <teamId> <channelId>').description('Read channel messages').option('-n, --limit <n>', 'number of messages', '10')
    .action(handle((tid, cid, opts) => readChannel(tid, cid, parseInt(opts.limit))));
channels.command('send <teamId> <channelId> <message>').description('Send to channel').action(handle(sendChannel));

// Meetings
const meetings = program.command('meetings').description('Meeting commands');
meetings.command('list').description('List upcoming meetings').action(handle(listMeetings));
meetings.command('create <subject> <start> <end>').description('Create a meeting (e.g. "2pm" "3pm")').action(handle(createMeeting));

// Status
const status = program.command('status').description('Presence/status commands');
status.command('set <status> [message]').description('Set status (available|busy|dnd|away|offline|brb)').action(handle(setStatus));
status.command('get').description('Get your current status').action(handle(() => getStatus('me')));

program.parse();
