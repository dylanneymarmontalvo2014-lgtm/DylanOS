
class Component extends DCLogic {
  constructor(props) {
    super(props);
    this.state = {
      openPanel: null,
      theme: 'dark',
      dndOn: false,
      wifiChipOn: true,
      btChipOn: true,
      pwValue: '',
      pwError: false,
      shakeCount: 0,
      unlocked: false
    };
  }

  toggle(name) {
    const cur = this.state.openPanel;
    this.setState({ openPanel: cur === name ? null : name });
  }

  closePanel() {
    this.setState({ openPanel: null });
  }

  toggleTheme() {
    this.setState({ theme: this.state.theme === 'dark' ? 'light' : 'dark' });
  }

  toggleDnd() {
    this.setState({ dndOn: !this.state.dndOn });
  }

  toggleWifiChip() {
    this.setState({ wifiChipOn: !this.state.wifiChipOn });
  }

  toggleBtChip() {
    this.setState({ btChipOn: !this.state.btChipOn });
  }

  onPwInput(e) {
    this.setState({ pwValue: e.target.value, pwError: false });
  }

  onPwKey(e) {
    if (e.key === 'Enter') this.tryUnlock();
  }

  tryUnlock() {
    const expected = this.props.password ?? '1234';
    if (this.state.pwValue === expected) {
      this.setState({ unlocked: true, pwError: false, pwValue: '' });
    } else {
      this.setState({ pwError: true, pwValue: '', shakeCount: this.state.shakeCount + 1 });
    }
  }

  renderVals() {
    const batteryPercent = this.props.batteryPercent ?? 78;
    const avatarUrl = this.props.avatarUrl ?? '';
    const open = this.state.openPanel;

    const forecast = [
      { label: 'Mié', hi: 23, lo: 14 },
      { label: 'Jue', hi: 24, lo: 15 },
      { label: 'Vie', hi: 22, lo: 13 },
      { label: 'Sáb', hi: 20, lo: 12 },
      { label: 'Dom', hi: 21, lo: 13 }
    ];

    const weekdays = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];
    const calNums = [27,28,29,30,31,1,2, 3,4,5,6,7,8,9, 10,11,12,13,14,15,16, 17,18,19,20,21,22,23, 24,25,26,27,28,29,30];
    const today = 4;
    const calendarDays = calNums.map((n, i) => {
      const isToday = n === today && i >= 7 && i < 14;
      const isOtherMonth = i < 7 && n > 20;
      return {
        n,
        color: isToday ? '#ffffff' : (isOtherMonth ? 'rgba(255,255,255,0.25)' : 'rgba(255,255,255,0.75)'),
        bg: isToday ? '#e11d2a' : 'transparent'
      };
    });

    const reminders = [
      { label: 'Estudiar para examen', done: false, ringColor: 'rgba(255,255,255,0.3)', fill: 'transparent', textColor: 'rgba(255,255,255,0.75)' },
      { label: 'Editar video de DylanTube', done: true, ringColor: '#e11d2a', fill: '#e11d2a', textColor: 'rgba(255,255,255,0.45)' },
      { label: 'Revisar proyecto DylanOS', done: false, ringColor: 'rgba(255,255,255,0.3)', fill: 'transparent', textColor: 'rgba(255,255,255,0.75)' },
      { label: 'Entrenar', done: false, ringColor: 'rgba(255,255,255,0.3)', fill: 'transparent', textColor: 'rgba(255,255,255,0.75)' }
    ];

    return {
      username: this.props.username ?? 'Dylan Rodríguez',
      avatarUrl: avatarUrl,
      hasAvatar: !!avatarUrl,
      noAvatar: !avatarUrl,

      timeHour: this.props.timeHour ?? '09',
      timeMinute: this.props.timeMinute ?? '00',
      timeAmPm: this.props.timeAmPm ?? 'PM',
      dateText: this.props.dateText ?? 'Martes, 04 de agosto',
      clockTimeText: this.props.clockTimeText ?? '9:00 PM',

      batteryPercent: batteryPercent,
      batteryFillWidth: Math.max(1, Math.round((batteryPercent / 100) * 19)),
      batteryDashOffset: Math.round(157 - (157 * batteryPercent) / 100),
      storageFree: this.props.storageFree ?? '237 GB',

      weatherTemp: this.props.weatherTemp ?? 19,
      weatherCondition: this.props.weatherCondition ?? 'Nublado',
      forecast: forecast,

      eventTitle: this.props.eventTitle ?? 'Reunión de proyecto',
      eventTime: this.props.eventTime ?? 'Mañana · 10:00 AM – 11:30 AM',

      trackTitle: this.props.trackTitle ?? 'Dream It Possible',
      trackArtist: this.props.trackArtist ?? 'Delacey',
      trackProgress: '42%',
      trackElapsed: '1:23',
      trackDuration: '3:24',

      calendarMonth: 'Agosto 2025',
      weekdays: weekdays,
      calendarDays: calendarDays,
      reminders: reminders,

      openPanel: open,
      anyPanelOpen: !!open,
      isWifiOpen: open === 'wifi',
      isBtOpen: open === 'bluetooth',
      isDisplayOpen: open === 'display',
      isBatteryOpen: open === 'battery',
      wifiOpenClass: open === 'wifi' ? 'is-open' : '',
      btOpenClass: open === 'bluetooth' ? 'is-open' : '',
      displayOpenClass: open === 'display' ? 'is-open' : '',
      batteryOpenClass: open === 'battery' ? 'is-open' : '',

      onWifiClick: () => this.toggle('wifi'),
      onBtClick: () => this.toggle('bluetooth'),
      onDisplayClick: () => this.toggle('display'),
      onBatteryClick: () => this.toggle('battery'),
      closeAll: () => this.closePanel(),

      themeFilter: this.state.theme === 'light' ? 'invert(1) hue-rotate(180deg)' : 'none',
      themeLabel: this.state.theme === 'light' ? 'Modo claro' : 'Modo oscuro',
      themeChipClass: this.state.theme === 'light' ? 'is-open' : '',
      dndChipClass: this.state.dndOn ? 'is-open' : '',
      wifiChipClass: this.state.wifiChipOn ? 'is-open' : '',
      btChipClass: this.state.btChipOn ? 'is-open' : '',
      onToggleTheme: () => this.toggleTheme(),
      onToggleDnd: () => this.toggleDnd(),
      onToggleWifiChip: () => this.toggleWifiChip(),
      onToggleBtChip: () => this.toggleBtChip(),

      pwValue: this.state.pwValue,
      pwError: this.state.pwError,
      pwErrorClass: this.state.pwError ? 'is-error' : '',
      shakeClass: this.state.shakeCount === 0 ? '' : (this.state.shakeCount % 2 ? 'pw-shake-a' : 'pw-shake-b'),
      lockText: this.state.unlocked ? 'Desbloqueado' : 'Bloqueado',
      onPwInput: (e) => this.onPwInput(e),
      onPwKey: (e) => this.onPwKey(e),
      onUnlock: () => this.tryUnlock()
    };
  }
}
