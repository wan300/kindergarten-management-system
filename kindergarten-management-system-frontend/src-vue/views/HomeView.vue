<script setup>
  import {
    ArrowRight,
    BookOpen,
    CalendarCheck,
    HeartHandshake,
    Sprout
  } from "lucide-vue-next";
</script>
<template>
  <div class="public-shell">
    <header class="public-header">
      <RouterLink class="brand-lockup" to="/"><img class="brand-mark" src="/assets/brand/para-kindergarten-logo.png" alt="" /><span><strong class="brand-name">ParaKindergarten</strong><small class="brand-subtitle">家园共育 · 记录成长</small></span></RouterLink>
      <nav class="public-nav" aria-label="登录入口">
        <RouterLink to="/login">教师登录</RouterLink>
        <RouterLink to="/parent_login">家长登录</RouterLink>
        <RouterLink to="/child_login">儿童空间</RouterLink>
        <RouterLink to="/admin_login">园所管理</RouterLink>
      </nav>
    </header>
    <main>
      <section class="hero">
        <div><span class="eyebrow">在园，在家，一起陪伴。</span>
          <h1>留住日常，<br /><em>看见成长。</em></h1>
          <p class="hero-copy">一张照片，一段视频，一次小小的观察。<br />让家长和老师一起记录孩子的日常，<br />也让每一次回顾，都多一份了解。</p>
          <div class="hero-actions">
            <RouterLink class="button button-primary" to="/login">我是老师
              <ArrowRight :size="16" />
            </RouterLink>
            <RouterLink class="button button-light" to="/parent_login">我是家长</RouterLink>
          </div>
        </div>
        <div class="journal-cover">
          <div class="cover-top">
            <Sprout :size="23" /><span>成长手记</span><span class="cover-small">每一个日常，都值得记下</span>
          </div>
          <div class="cover-art" aria-hidden="true"><svg viewBox="0 0 500 230">
              <rect width="500" height="230" fill="#e9e5d9" />
              <ellipse cx="252" cy="199" rx="151" ry="14" fill="#d5d0c0" />
              <rect x="132" y="111" width="58" height="81" fill="#b68769" />
              <path d="m190 111 17-11v81l-17 11Z" fill="#956c51" />
              <rect x="309" y="111" width="58" height="81" fill="#8e9b7a" />
              <path d="m367 111 17-11v81l-17 11Z" fill="#6f7d5e" />
              <rect x="123" y="84" width="254" height="31" fill="#ceba83" />
              <path d="m123 84 17-11h254l-17 11Z" fill="#e0ce9a" />
              <path d="m214 81 42-64 42 64Z" fill="#7e9690" />
              <path d="m298 81 15-11-42-64-15 11Z" fill="#607873" />
              <circle cx="411" cy="181" r="17" fill="#ba9d69" />
            </svg></div>
          <div class="cover-body"><span class="cover-small">从一次小观察开始</span>
            <h2>今天，孩子有什么新发现？</h2>
            <p>记下他说的话、做的事，<br />把这些片刻，慢慢连成成长的故事。</p>
            <div class="cover-footer"><span>照片 / 视频 / 文字</span>
              <BookOpen :size="19" />
            </div>
          </div>
        </div>
      </section>
      <section class="home-features">
        <article><span class="feature-number">01</span>
          <CalendarCheck :size="20" />
          <h2>日常管理，清楚有序</h2>
          <p>孩子档案、班级与考勤，让老师更方便地处理每天的工作。</p>
        </article>
        <article><span class="feature-number">02</span>
          <HeartHandshake :size="20" />
          <h2>家园观察，放在一起</h2>
          <p>在家和在园的照片、视频与文字，按日期汇集到孩子的成长记录里。</p>
        </article>
        <article><span class="feature-number">03</span>
          <BookOpen :size="20" />
          <h2>随时回顾，多一份理解</h2>
          <p>浏览原始记录，参考文字摘要，一起留意孩子的兴趣与日常变化。</p>
        </article>
      </section>
    </main>
    <footer class="home-footer"><span>© {{ new Date().getFullYear() }} ParaKindergarten</span><span>陪伴每一个小小的成长</span></footer>
  </div>
</template>
<style scoped>
  .journal-cover {
    background: #fffdf6;
    border: 1px solid #dfe2d4;
    border-radius: 14px;
    box-shadow: 0 22px 50px #4a51351a;
    transform: rotate(1deg);
    overflow: hidden;
    max-width: 490px;
    width: 100%
  }

  .cover-top {
    display: flex;
    align-items: center;
    gap: 9px;
    padding: 20px 23px;
    color: #647953;
    font-size: 14px
  }

  .cover-small {
    font-size: 11px;
    color: #7e8b70
  }

  .cover-top .cover-small {
    margin-left: auto
  }

  .cover-art {
    margin: 0 20px;
    overflow: hidden;
    border-radius: 7px
  }

  .cover-art svg {
    display: block;
    width: 100%
  }

  .cover-body {
    padding: 22px 25px
  }

  .cover-body h2 {
    font-size: 21px;
    font-weight: 550;
    letter-spacing: -.025em;
    margin: 8px 0
  }

  .cover-body p {
    font-size: 14px;
    color: #7a856b;
    line-height: 1.8
  }

  .cover-footer {
    border-top: 1px solid #e5e7da;
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 24px;
    padding-top: 16px;
    font-size: 11px;
    color: #7a8869
  }

  .home-features {
    max-width: 1176px;
    margin: 0 auto 60px;
    border-top: 1px solid #dfe3d5;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 40px;
    padding-top: 30px
  }

  .home-features article {
    position: relative;
    color: #607a4c
  }

  .home-features h2 {
    font-size: 17px;
    font-weight: 550;
    color: #3e4e32;
    margin: 15px 0 9px
  }

  .home-features p {
    font-size: 14px;
    line-height: 1.8;
    color: #7a856c;
    margin: 0
  }

  .feature-number {
    float: right;
    font-size: 12px;
    color: #9ba58e
  }

  .home-footer {
    max-width: 1176px;
    margin: auto;
    padding: 20px 0 28px;
    border-top: 1px solid #e1e6d6;
    display: flex;
    justify-content: space-between;
    gap: 10px;
    font-size: 11px;
    color: #788969
  }

  @media(max-width:1240px) {

    .home-features,
    .home-footer {
      margin-left: 32px;
      margin-right: 32px
    }
  }

  @media(max-width:820px) {
    .journal-cover {
      transform: none;
      max-width: 600px
    }

    .home-features {
      grid-template-columns: 1fr;
      gap: 28px
    }

    .cover-top .cover-small {
      display: none
    }

    .home-footer {
      flex-wrap: wrap
    }
  }
</style>