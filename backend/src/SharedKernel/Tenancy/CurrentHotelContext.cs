namespace HotelMarketplace.SharedKernel.Tenancy;

public sealed class CurrentHotelContext : ICurrentHotelContext
{
    private static readonly AsyncLocal<HotelScope?> CurrentScope = new();

    public Guid? HotelId => CurrentScope.Value?.HotelId;

    public bool IsHotelScopeEnforced => CurrentScope.Value is not null;

    public IDisposable UseHotel(Guid hotelId)
    {
        HotelScope? previousScope = CurrentScope.Value;
        CurrentScope.Value = new HotelScope(hotelId);

        return new ScopeReset(() => CurrentScope.Value = previousScope);
    }

    private sealed record HotelScope(Guid HotelId);

    private sealed class ScopeReset : IDisposable
    {
        private readonly Action _reset;
        private bool _isDisposed;

        public ScopeReset(Action reset)
        {
            _reset = reset;
        }

        public void Dispose()
        {
            if (_isDisposed)
            {
                return;
            }

            _reset();
            _isDisposed = true;
        }
    }
}
