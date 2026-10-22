using System;
using DemoApp.Core;
using NUnit.Framework;

namespace DemoApp.Tests
{
    [TestFixture]
    public class PriceCalculatorTests
    {
        [TestCase(100, 10, 90)]
        [TestCase(200, 25, 150)]
        [TestCase(50, 0, 50)]
        [TestCase(80, 100, 0)]
        public void ApplyDiscount_ReturnsDiscountedPrice(decimal price, int percent, decimal expected)
        {
            Assert.That(PriceCalculator.ApplyDiscount(price, percent), Is.EqualTo(expected));
        }

        [Test]
        public void ApplyDiscount_RejectsNegativePrice()
        {
            Assert.Throws<ArgumentOutOfRangeException>(() => PriceCalculator.ApplyDiscount(-1, 10));
        }

        [TestCase(-5)]
        [TestCase(101)]
        public void ApplyDiscount_RejectsInvalidPercent(int percent)
        {
            Assert.Throws<ArgumentOutOfRangeException>(() => PriceCalculator.ApplyDiscount(100, percent));
        }
    }
}
