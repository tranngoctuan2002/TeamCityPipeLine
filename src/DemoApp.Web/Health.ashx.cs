using System.Web;
using DemoApp.Core;

namespace DemoApp.Web
{
    /// <summary>
    /// Health endpoint used by the smoke test: returns "OK &lt;version&gt;" with HTTP 200,
    /// or HTTP 500 if the core logic gives a wrong answer.
    /// </summary>
    public class HealthHandler : IHttpHandler
    {
        public bool IsReusable
        {
            get { return true; }
        }

        public void ProcessRequest(HttpContext context)
        {
            context.Response.ContentType = "text/plain";
            context.Response.Cache.SetCacheability(HttpCacheability.NoCache);

            bool coreWorks = PriceCalculator.ApplyDiscount(100m, 10) == 90m;
            if (!coreWorks)
            {
                context.Response.StatusCode = 500;
                context.Response.Write("FAIL " + AppVersion.Current);
                return;
            }

            context.Response.Write("OK " + AppVersion.Current);
        }
    }
}
