using System.Configuration;
using DemoApp.Core;

namespace DemoApp.Web
{
    public partial class DefaultPage : System.Web.UI.Page
    {
        protected string Headline
        {
            get { return SiteInfo.Headline; }
        }

        protected string DiscountedPrice
        {
            get { return PriceCalculator.ApplyDiscount(100m, 10).ToString("0.00"); }
        }

        protected string EnvironmentName
        {
            get { return ConfigurationManager.AppSettings["Environment"] ?? "Unknown"; }
        }

        protected string Version
        {
            get { return AppVersion.Current; }
        }
    }
}
