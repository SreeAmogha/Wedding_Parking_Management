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
           <a href="/entry-exit" data-page="entry-exit" data-role="attendant">
               <span>🚘</span> Entry / Exit
           </a>
           <a href="/history" data-page="history">
               <span>◷</span> Parking History
           </a>
           <a href="/events" data-page="events" data-role="admin">
               <span>📅</span> Manage Events
           </a>
       </nav>
       <div class="sidebar-footer">
           <p>Smart Wedding Parking</p>
           <small>Attendant Panel</small>
       </div>
   </aside>
`;
document.addEventListener("DOMContentLoaded", async () => {
   const container = document.getElementById("sidebar-container");
   if (!container) return;
   container.innerHTML = sidebarHTML;
   try {
       const { supabase } = await import("./app.js");
       const { data: { session } } = await supabase.auth.getSession();
       if (!session) return;
       const { data: profile, error } = await supabase
           .from("profiles")
           .select("role")
           .eq("id", session.user.id)
           .single();
       if (error || !profile) {
           console.error("Could not load staff role for navigation:", error);
           return;
       }
       container.querySelectorAll("[data-role]").forEach(link => {
           link.hidden = link.dataset.role !== profile.role;
       });
       const footerRole = container.querySelector(".sidebar-footer small");
       footerRole.textContent = profile.role === "admin" ? "Administrator Panel" : "Attendant Panel";
       document.querySelectorAll(".quick-links [data-role]").forEach(link => {
           link.hidden = link.dataset.role !== profile.role;
       });
   } catch (error) {
       console.error("Could not initialize role-based navigation:", error);
   }
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