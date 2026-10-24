const sidebarHTML = `
   <aside class="sidebar">
       <div class="sidebar-brand">
           <span class="brand-icon">🚗</span>
           <div>
               <h2>Smart Parking</h2>
               <p>WEDDING MANAGEMENT</p>
           </div>
       </div>
       <nav class="sidebar-nav">
           <a href="dashboard.html" data-page="dashboard">
               <span>▦</span> Dashboard
           </a>
           <a href="/entry-exit" data-page="entry-exit">
               <span>🚘</span> Entry / Exit
           </a>
           <a href="/history" data-page="history">
               <span>◷</span> Parking History
           </a>
           <a href="/events" data-page="events">
               <span>📅</span> Manage Events
           </a>
       </nav>
       <div class="sidebar-footer">
           <p>Smart Wedding Parking</p>
           <small>Attendant Panel</small>
       </div>
   </aside>
`;
document.addEventListener("DOMContentLoaded", () => {
   const container = document.getElementById("sidebar-container");
   if (!container) return;
   container.innerHTML = sidebarHTML;
   // Determine current page from filename
   const path = window.location.pathname;
   const filename = path.split('/').pop() || 'dashboard.html';
   let currentPage = 'dashboard';
   if (filename.includes('entry-exit'))    currentPage = 'entry-exit';
   else if (filename.includes('history'))  currentPage = 'history';
   else if (filename.includes('events'))   currentPage = 'events';
   const activeLink = container.querySelector(`[data-page="${currentPage}"]`);
   if (activeLink) activeLink.classList.add('active');
});