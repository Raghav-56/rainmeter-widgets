from pathlib import Path
import configparser
from datetime import datetime
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
config = configparser.ConfigParser(interpolation=None, strict=False)
config.optionxform = str
config.read(root / 'MementoMori/Skins/MementoMori/Meter.ini')
for year, month, day, age in [(2000, 1, 1, 60), (1990, 6, 15, 80)]:
    lua = LuaRuntime()
    values = dict(config['Variables'])
    values.update(BirthYear=str(year), BirthMonth=str(month), BirthDay=str(day), ReferenceAge=str(age))
    lua.globals().variables = lua.table_from(values)
    lua.execute('''
        options = {}; writes = {}
        SKIN = {
            GetVariable = function(self, key, default) return variables[key] or default end,
            MakePathAbsolute = function(self, path) return path end,
            Bang = function(self, command, meter, option, value, path)
                if command == '!SetOption' then
                    options[meter] = options[meter] or {}
                    options[meter][option] = value
                elseif command == '!WriteKeyValue' then writes.path = path end
            end
        }
    ''')
    lua.execute((root / 'MementoMori/Skins/MementoMori/@Resources/Clock.lua').read_text(encoding='utf-8'))
    lua.execute('Initialize(); ApplyView()')
    options = lua.globals().options
    assert options.Horizon.Text == f'{age}-year horizon'
    assert str(year + age) in options.Target.Text
    expected = int((datetime(year + age, month, day) - datetime.now()).total_seconds() // 604800)
    assert options.Weeks.Text == f'{max(0, expected):,}'
    assert options.Panel.H == '196'
    lua.execute('ToggleMini()')
    assert options.Panel.H == '44'
    lua.execute('ToggleView()')
    assert options.Panel.H == '514'
    lua.execute('ToggleToday()')
    assert lua.globals().writes.path == '@Resources\\User.inc'
    print(f'PASS: Memento Mori example {year}, age {age}, actual week count, views and separate settings persistence')

lua = LuaRuntime()
lua.execute((root / 'CLIProxyAccounts/CLIProxyAccounts/@Resources/Snapshot.lua').read_text(encoding='utf-8'))
lua.execute('SelfTest()')
print('PASS: accounts Lua self-test in isolated Lua 5.1')
