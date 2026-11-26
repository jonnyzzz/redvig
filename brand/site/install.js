const platforms = document.querySelector('.platforms');
const platformButtons = Array.from(platforms.querySelectorAll('[data-platform]'));
const commands = Array.from(document.querySelectorAll('[data-command]'));
const copyStatus = document.querySelector('.copy-status');

function showCommand(platform) {
  for (const button of platformButtons) {
    button.setAttribute('aria-pressed', String(button.dataset.platform === platform));
  }
  for (const command of commands) {
    command.hidden = command.dataset.command !== platform;
  }
  copyStatus.textContent = '';
}

for (const button of platformButtons) {
  button.addEventListener('click', () => showCommand(button.dataset.platform));
}

if (navigator.clipboard) {
  for (const command of commands) {
    const button = command.querySelector('.copy');
    const code = command.querySelector('code');
    button.hidden = false;
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        copyStatus.textContent = 'Command copied.';
      } catch {
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(code);
        selection.removeAllRanges();
        selection.addRange(range);
        copyStatus.textContent = 'Command selected. Copy it with your keyboard.';
      }
    });
  }
}

platforms.hidden = false;
showCommand('mac');
