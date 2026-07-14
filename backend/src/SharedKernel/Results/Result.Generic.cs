namespace HotelMarketplace.SharedKernel.Results;

public sealed class Result<TValue> : Result
{
    private readonly TValue? _value;

    internal Result(TValue? value, bool isSuccess, ResultError error)
        : base(isSuccess, error)
    {
        _value = value;
    }

    public TValue Value
    {
        get
        {
            if (IsFailure)
            {
                throw new InvalidOperationException("The value of a failed result cannot be accessed.");
            }

            return _value ?? throw new InvalidOperationException(ResultError.NullValue.Message);
        }
    }

    public static implicit operator Result<TValue>(TValue value)
    {
        return value is null ? Failure<TValue>(ResultError.NullValue) : Success(value);
    }
}
