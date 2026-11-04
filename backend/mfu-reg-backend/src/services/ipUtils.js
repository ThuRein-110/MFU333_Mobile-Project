
const isIpInRange = (ip, cidr) => {
    const [range, bits = "32"] = cidr.split("/");

    const ipToNumber = (value) => {
        const parts = value.split(".");

        if (
            parts.length !== 4 ||
            parts.some(part =>
                !/^\d+$/.test(part) ||
                Number(part) > 255
            )
        ) {
            return null;
        }

        return parts.reduce(
            (result, part) =>
                (result << 8) + Number(part),
            0
        ) >>> 0;
    };

    const ipNumber = ipToNumber(ip);
    const rangeNumber = ipToNumber(range);
    const prefix = Number(bits);

    if (
        ipNumber === null ||
        rangeNumber === null ||
        !Number.isInteger(prefix) ||
        prefix < 0 ||
        prefix > 32
    ) {
        return false;
    }

    const mask = prefix === 0
        ? 0
        : (0xFFFFFFFF << (32 - prefix)) >>> 0;

    return (ipNumber & mask) === (rangeNumber & mask);
};

module.exports = { isIpInRange };
