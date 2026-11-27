/* Growth OS DS v2.8.0 · motion helper (IMAGERY.md §0 R6). ~1 KB, no deps.
   - [data-gos-reveal] elements that start below the fold fade/translate in (.gos-rv → .is-in)
   - [data-gos-count] numbers count up once (width-stable: n-digit numbers start at 10^(n-1))
   Everything is skipped under prefers-reduced-motion. Reference: site/src/kit.py MOTION_JS. */
(function(){if(!('IntersectionObserver' in window))return;
var rm=matchMedia('(prefers-reduced-motion: reduce)').matches,H=innerHeight;
function count(el){if(rm||el.dataset.gosCounted)return;el.dataset.gosCounted=1;var w=document.createTreeWalker(el,4),n,ns=[];while(n=w.nextNode())if(/\d/.test(n.nodeValue))ns.push([n,n.nodeValue]);
 var t0=performance.now();function f(t){var k=Math.min(1,(t-t0)/1100),e=1-Math.pow(1-k,3);ns.forEach(function(p){p[0].nodeValue=p[1].replace(/\d+/g,function(d){var lo=d.length>1?Math.pow(10,d.length-1):0;return String(Math.round(lo+(+d-lo)*e))})});if(k<1)requestAnimationFrame(f)}requestAnimationFrame(f)}
var io=new IntersectionObserver(function(es){es.forEach(function(e){if(!e.isIntersecting)return;var el=e.target;el.classList.add('is-in');if(el.hasAttribute('data-gos-count'))count(el);io.unobserve(el)})},{rootMargin:'0px 0px -8% 0px',threshold:0});
document.querySelectorAll('[data-gos-count]').forEach(function(el){io.observe(el)});
if(rm)return;var i=0,last=null;
document.querySelectorAll('[data-gos-reveal]').forEach(function(el){if(el.getBoundingClientRect().top<H*.92)return;i=(el.parentElement===last)?i+1:0;last=el.parentElement;el.style.transitionDelay=Math.min(i,4)*70+'ms';el.classList.add('gos-rv');io.observe(el)});
})();
