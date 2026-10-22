using System;

namespace DemoApp.Core
{
    /// <summary>
    /// Small piece of business logic so the pipeline has something real to test.
    /// Demo 2 introduces a bug here (branch demo/2-discount-bug).
    /// </summary>
    public static class PriceCalculator
    {
        public static decimal ApplyDiscount(decimal price, int percent)
        {
            if (price < 0)
            {
                throw new ArgumentOutOfRangeException(nameof(price), "Price cannot be negative.");
            }

            if (percent < 0 || percent > 100)
            {
                throw new ArgumentOutOfRangeException(nameof(percent), "Discount must be between 0 and 100.");
            }

            return price - (price * percent / 100m);
        }
    }
}
