namespace HotelMarketplace.SharedKernel.Results;

public class Result
{
    protected Result(bool isSuccess, ResultError error)
    {
        if (isSuccess && error != ResultError.None)
        {
            throw new InvalidOperationException("A successful result cannot contain an error.");
        }

        if (!isSuccess && error == ResultError.None)
        {
            throw new InvalidOperationException("A failed result must contain an error.");
        }

        IsSuccess = isSuccess;
        Error = error;
    }

    public bool IsSuccess { get; }

    public bool IsFailure => !IsSuccess;

    public ResultError Error { get; }

    public static Result Success() => new(true, ResultError.None);

    public static Result Failure(ResultError error) => new(false, error);

    public static Result<TValue> Success<TValue>(TValue value) => new(value, true, ResultError.None);

    public static Result<TValue> Failure<TValue>(ResultError error) => new(default, false, error);
}
