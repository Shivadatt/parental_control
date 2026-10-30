import qa_ui as q, time, os, sys
from PIL import Image

S = '5HXWRGQ4IFU8WS4T'


def shot(n):
    return q.shot(S, n)


def blue_rows(ymin=300, ymax=2200, path='_probe.png'):
    shot(path)
    im = Image.open(os.path.join(q.EVID, path)); px = im.load()
    rows = []
    for y in range(ymin, ymax):
        c = 0
        for x in range(0, 1080, 3):
            r, g, b = px[x, y][:3]
            if b > 180 and r < 110 and g < 130:
                c += 1
        if c > 50:
            rows.append(y)
    return (rows[0], rows[-1]) if rows else None


def signin(user, pw, tag):
    # role-select: tap the SECOND "Sign in" (Child Mode) by y ordering
    q.adb(S, 'shell', 'input', 'keyevent', '111'); time.sleep(0.8)
    q.adb(S, 'shell', 'am', 'start', '-n',
          'com.parentcontrol.parent_control/.MainActivity')
    time.sleep(3)
    shot(f'{tag}-a-rolesel.png')
    # Child Mode Sign in sits lower than Parent Mode Sign in
    q.adb(S, 'shell', 'input', 'tap', '318', '2211'); time.sleep(2.5)
    shot(f'{tag}-b-signin-page.png')
    im = Image.open(os.path.join(q.EVID, f'{tag}-b-signin-page.png')); px = im.load()
    # locate the two outlined field boxes by their grey border rows
    def type_into(cy, value):
        q.adb(S, 'shell', 'input', 'tap', '540', str(cy)); time.sleep(1.2)
        q.adb(S, 'shell', "input text '" + value + "'"); time.sleep(1.0)
        q.adb(S, 'shell', 'input', 'keyevent', '4'); time.sleep(0.7)
        q.adb(S, 'shell', 'input', 'keyevent', '111'); time.sleep(1.2)
    # email field ~1231, password ~1429 on this page (1080x2400, no keyboard)
    type_into(1231, user)
    type_into(1429, pw)
    shot(f'{tag}-c-filled.png')
    q.adb(S, 'shell', 'input', 'tap', '540', '1650'); time.sleep(9)
    shot(f'{tag}-d-after.png')


if __name__ == '__main__':
    signin(os.environ['QA_USER'], os.environ['QA_PASS'], sys.argv[1])
