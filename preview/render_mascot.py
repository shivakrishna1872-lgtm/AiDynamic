from PIL import Image, ImageDraw, ImageFont, ImageFilter
from math import sin, cos
from pathlib import Path

W,H=900,640
OUT=Path(__file__).with_name('mascot-animation.gif')
frames=[]

def font(size,bold=False):
    p='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    try:return ImageFont.truetype(p,size)
    except:return ImageFont.load_default()

def rounded(draw,box,r,fill,outline=None,width=1): draw.rounded_rectangle(box,radius=r,fill=fill,outline=outline,width=width)
def gradient(im,box,top,bottom,r):
    x0,y0,x1,y1=box; h=y1-y0
    strip=Image.new('RGB',(x1-x0,h))
    px=strip.load()
    for y in range(h):
        t=y/max(1,h-1); c=tuple(int(top[i]*(1-t)+bottom[i]*t) for i in range(3))
        for x in range(x1-x0):px[x,y]=c
    mask=Image.new('L',strip.size,0); ImageDraw.Draw(mask).rounded_rectangle((0,0,strip.width-1,strip.height-1),radius=r,fill=255)
    im.paste(strip,(x0,y0),mask)

def make_frame(mood, phase):
    im=Image.new('RGB',(W,H),(12,17,29)); d=ImageDraw.Draw(im)
    # ambient gradient and light pool
    for y in range(H):
        t=y/H; c=(int(22-10*t),int(30-12*t),int(51-20*t)); d.line((0,y,W,y),fill=c)
    glow=Image.new('RGBA',(W,H),(0,0,0,0)); gd=ImageDraw.Draw(glow)
    gd.ellipse((235,90,700,570),fill=(69,105,255,38)); glow=glow.filter(ImageFilter.GaussianBlur(52)); im=Image.alpha_composite(im.convert('RGBA'),glow).convert('RGB'); d=ImageDraw.Draw(im)
    d.text((58,48),'Your little AI companion',font=font(24,True),fill='#f5f7ff')
    d.text((59,82),'A playful, expressive friend with a tiny island home',font=font(13),fill='#aab5ce')
    # phone
    rounded(d,(313,120,587,580),49,'#12151d','#737d92',3)
    rounded(d,(324,132,576,568),39,'#f1f4f8')
    rounded(d,(408,132,492,154),11,'#080a0e')
    d.text((344,165),'9:41',font=font(11,True),fill='#202838')
    d.text((346,198),'Good morning',font=font(17,True),fill='#192234')
    d.text((346,222),'What shall we make today?',font=font(11),fill='#717d90')
    rounded(d,(343,445,557,523),20,'#ffffff','#e2e7ef')
    d.text((361,455),'Your local assistant',font=font(11,True),fill='#243049')
    d.text((361,476),'No cloud keys. Just a little help.',font=font(10),fill='#778196')
    rounded(d,(361,494,454,518),12,'#edf1ff'); d.text((375,500),'Start a chat',font=font(9,True),fill='#5068c9')
    d.text((345,542),'Today',font=font(9),fill='#b5bdca')
    # island home-base capsule with a tiny peek-in opening on right
    rounded(d,(358,144,541,195),26,'#050609','#303743',1)
    d.line((375,153,524,153),fill='#282c35',width=1)
    d.ellipse((381,166,389,174),fill='#69e5a4')
    d.text((401,162),'ISLAND BUDDY',font=font(8,True),fill='#d4dae6')
    # stable mascot geometry / positions
    bounce={'idle':0,'wave':-6,'curious':0,'thinking':-2,'idea':-9,'celebrate':-12}.get(mood,0)
    tilt={'idle':0,'wave':-2,'curious':-11,'thinking':3+sin(phase)*2,'idea':3,'celebrate':-3}.get(mood,0)
    cx,cy=526,250+bounce
    # legs/body
    for lx,ang in [(cx-15,0),(cx+15,0)]:
        d.rounded_rectangle((lx-5,cy+48,lx+5,cy+67),radius=5,fill='#5870cf')
    d.ellipse((cx-24,cy+23,cx+24,cy+58),fill='#627bd8')
    d.ellipse((cx-12,cy+26,cx+6,cy+31),fill='#b9c6ff')
    # arms at consistent origins
    waving=mood in ('wave','celebrate')
    thinking=mood=='thinking'
    # left arm angled up when celebration; default short curved-ish limb
    if mood=='celebrate':
        d.line((cx-24,cy+34,cx-43,cy+17),fill='#f2ae96',width=10); d.ellipse((cx-49,cy+11,cx-39,cy+21),fill='#f2ae96')
        d.line((cx+24,cy+34,cx+42,cy+16),fill='#f2ae96',width=10); d.ellipse((cx+37,cy+10,cx+47,cy+20),fill='#f2ae96')
    elif mood=='wave':
        dy=int(4*sin(phase*8)); d.line((cx-24,cy+34,cx-38,cy+49),fill='#f2ae96',width=10)
        d.line((cx+24,cy+34,cx+41,cy+9+dy),fill='#f2ae96',width=10); d.ellipse((cx+36,cy+3+dy,cx+47,cy+14+dy),fill='#f2ae96')
    elif thinking:
        d.line((cx-24,cy+34,cx-40,cy+43),fill='#f2ae96',width=10)
        d.line((cx+24,cy+34,cx+30,cy+16),fill='#f2ae96',width=10); d.ellipse((cx+25,cy+10,cx+35,cy+20),fill='#f2ae96')
    else:
        d.line((cx-24,cy+34,cx-37,cy+45),fill='#f2ae96',width=10); d.ellipse((cx-42,cy+40,cx-32,cy+50),fill='#f2ae96')
        d.line((cx+24,cy+34,cx+38,cy+43),fill='#f2ae96',width=10); d.ellipse((cx+33,cy+38,cx+43,cy+48),fill='#f2ae96')
    # head fixed shape, shaded toy gradient
    head=Image.new('RGBA',(118,118),(0,0,0,0)); hd=ImageDraw.Draw(head)
    for radius in range(53,0,-1):
        t=(53-radius)/53; color=(int(255-25*t),int(224-73*t),int(201-60*t),255)
        hd.ellipse((59-radius,59-radius,59+radius,59+radius),fill=color)
    hd.ellipse((17,10,72,37),fill=(255,255,255,85))
    hd.ellipse((17,17,101,101),outline=(255,241,231,220),width=2)
    # blush
    hd.ellipse((14,68,33,81),fill=(244,126,135,85));hd.ellipse((85,68,104,81),fill=(244,126,135,85))
    # eyes and expressions
    if mood=='celebrate':
        for ex in (47,91): hd.arc((ex-9,57,ex+9,77),190,345,fill=(62,43,59,255),width=4)
    elif mood=='thinking':
        for ex in (47,91):
            hd.ellipse((ex-8,55,ex+8,80),fill=(255,255,255,255)); hd.ellipse((ex-4,55,ex+4,67),fill=(40,48,75,255)); hd.ellipse((ex-2,56,ex+1,59),fill=(255,255,255,255))
    elif mood=='curious':
        hd.ellipse((37,55,56,82),fill=(255,255,255,255));hd.ellipse((82,57,101,81),fill=(255,255,255,255))
        hd.ellipse((44,61,52,75),fill=(40,48,75,255));hd.ellipse((88,61,96,75),fill=(40,48,75,255))
        hd.arc((34,45,59,57),190,300,fill=(112,72,81,255),width=3);hd.arc((80,45,104,58),190,345,fill=(112,72,81,255),width=3)
    elif mood=='idea':
        for ex in (47,91):
            hd.ellipse((ex-10,53,ex+10,83),fill=(255,255,255,255));hd.ellipse((ex-5,58,ex+5,77),fill=(39,48,77,255));hd.ellipse((ex-3,58,ex,62),fill=(255,255,255,255))
    else:
        for ex in (47,91):
            hd.ellipse((ex-9,56,ex+9,81),fill=(255,255,255,255));hd.ellipse((ex-5,61,ex+5,77),fill=(39,48,77,255));hd.ellipse((ex-3,61,ex,65),fill=(255,255,255,255))
    # mouth simple signature design with changing expressive shape
    if mood in ('idea','celebrate'):
        hd.ellipse((59,91,79,108),fill=(110,45,67,255)); hd.rounded_rectangle((63,93,76,98),radius=2,fill=(255,244,241,255))
    elif mood=='thinking':
        hd.rounded_rectangle((62,96,75,101),radius=3,fill=(110,55,70,255))
    elif mood=='curious':
        hd.ellipse((65,95,78,102),fill=(110,55,70,255))
    elif mood=='wave':
        hd.arc((56,87,87,111),5,170,fill=(123,47,67,255),width=5)
    else:
        hd.arc((55,86,89,111),5,170,fill=(123,47,67,255),width=5)
    rotated=head.rotate(tilt,resample=Image.Resampling.BICUBIC)
    im.paste(rotated,(cx-59,cy-57),rotated)
    d=ImageDraw.Draw(im)
    if mood=='thinking':
        for idx,(dx,dy) in enumerate([(35,-53),(47,-67),(61,-78)]):
            rr=4-idx*.7; yy=dy+int(sin(phase*3-idx*.7)*3)
            d.ellipse((cx+dx-rr,cy+yy-rr,cx+dx+rr,cy+yy+rr),fill=(188,209,255))
        d.ellipse((cx+25,cy+17,cx+36,cy+28),fill='#f3b098')
    if mood in ('idea','celebrate'):
        for sx,sy,r,col in [(cx+48,cy-58,7,'#ffe37b'),(cx+63,cy-34,4,'#91e8ff')]:
            d.polygon([(sx,sy-r),(sx+2,sy-2),(sx+r,sy),(sx+2,sy+2),(sx,sy+r),(sx-2,sy+2),(sx-r,sy),(sx-2,sy-2)],fill=col)
    captions={'idle':'Just hanging out','wave':"Oh! You\\'re here!",'curious':"What\\'s that?",'thinking':'Let me think…','idea':'I\\'ve got an idea!','celebrate':'We did it!'}
    cap=captions[mood]; d.text((350,376),cap,font=font(12,True),fill='#34415b')
    d.text((350,396),'Your local AI companion',font=font(10),fill='#596984')
    d.text((58,608),'Animation preview: idle / wave / curious / thoughtful / idea / celebrate / idle',font=font(11),fill='#8491aa')
    return im

sequence=[('idle',8),('wave',8),('curious',8),('thinking',18),('idea',6),('celebrate',10)]
for mood,count in sequence:
    for i in range(count): frames.append(make_frame(mood,i/8))
frames.append(make_frame('idle',0))
frames[0].save(OUT,save_all=True,append_images=frames[1:],duration=90,loop=0,optimize=False,disposal=2)
print(f'Wrote {OUT} ({len(frames)} frames, {OUT.stat().st_size} bytes)')
